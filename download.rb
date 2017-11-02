#!ruby
# -*- coding: utf-8 -*-

require 'openssl'
require 'json'
require 'uri'
require 'net/http'
require 'fileutils'

require 'mechanize'
require "active_record"
require "mail"

require './status.rb'
require './product.rb'

class String
  Tr_src="\\\\/:*?\"<>|\t"
  Tr_dst=%(￥／：＊？”＜＞｜)+" "
  def cut_byte(len=225)
    pstr=self
    while pstr.bytesize >len
      pstr=pstr[0..-2]
    end
    return pstr
  end
  def to_fname
    self.gsub(/[[:cntrl:]]/, '').tr(Tr_src,Tr_dst).strip.cut_byte
  end
end

# DB接続設定
ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     ENV['DB_SITE'],
  encoding: "utf8",
  port: 3306,
  username: ENV['DB_USERNAME'],
  password: ENV['DB_PASSWORD'],
  database: "webapi_development",
)

class Downloader
  Tlogin ="#{ENV['DL_SITE']}/webapi/auth.cgi?api=SYNO.API.Auth&version=2&method=login&account=#{ENV['DL_USERNAME']}&passwd=#{ENV['DL_PASSWORD']}&session=DownloadStation&format=sid"
  Tlogout="#{ENV['DL_SITE']}/webapi/auth.cgi?api=SYNO.API.Auth&version=2&method=logout&session=DownloadStation&sid="
  Purl   ="#{ENV['DL_SITE']}/webapi/DownloadStation/task.cgi"
  Dest_base="public/dl/pdf/"
  Pdf_dir='/dl/pdf/'
  Site=ENV['TG_SITE']
  SiteOp="/?page="

  def main
    dlset={}
    page=1

    browser = Mechanize.new
    browser.user_agent_alias = 'Windows IE 9'
    browser.verify_mode = OpenSSL::SSL::VERIFY_NONE

    while page>0
      url=Site
      url=Site+SiteOp+page.to_s if page>1
      pg=browser.get(url)
      page+=1
      pg.search('article.single-wrap').each do |ar|
        ele    = ar.at('a.single-name')
        href   = ele[:href]
        url    = Site+href
        next if dlset[href]
        if Product.exists?(url: url )
          return {action: :success, message: "完了しました", data: dlset,title: "完了(#{dlset.size})"}
        end

        auther = ar.at('div.single-infowrap a')
        genre  = ar.at('a.single-genre').text
        
        name=ele.text
        name="[#{auther.text}] "+name if auther
        name="(#{genre})"+name unless genre.include?("単行本")
        name=name.to_fname
        dlset[href]=name
        
        sg=pg.link_with(href: href , dom_class: 'single-name').click
        link=sg.link_with(href: href.sub("/item/","/item/dl_zip/"))
        unless link
          return {action: :link_expire, message: "link切れ:#{name}\n完了(#{dlset.size})", title: "link切れ"}
        end
        
        dup=Product.where(name: name).count
        pd=Product.new
        pd.url =url
        pd.name=name
        pd.status_id=1
        if dup>0
          name+=" - "+(dup+1).to_s
          pd.rename=name
        end
        ret=dl(url,name,sg)
        unless ret["success"]
          dlset[href]='StationError:'+ret[:message]
          send_error_mail('StationError:'+ret[:message])
          return {action: :station_err, message: 'StationError:'+ret[:message]}
        end
        pd.save
      end
    end
    return {action: :unk_error, message: "不明なエラー\n完了(#{dlset.size})", title: "不明なエラー"}
  rescue Mechanize::ResponseCodeError => e
    send_error_mail('SiteError:'+e.response_code)
    return {action: :site_err,code: e.response_code, message: 'SiteError:'+e.response_code}
  end

  def dl(url,name,pg)
    dl_url=pg.at('meta[name="twitter:image:src"]')[:content].sub(%r![^/]+\z!,'item.zip')

    ppara={api: "SYNO.DownloadStation.Task",
           version: "3",
           method: "create",
          }
    FileUtils.mkdir_p(Pdf_dir+name)
    res = Net::HTTP.get(URI.parse(Tlogin))

    sidb=JSON.parse(res)
    sid=sidb["data"]["sid"]

    ppara["uri"]=dl_url
    ppara["destination"]=Dest_base+name
    ppara["_sid"]=sid

    pres= Net::HTTP.post_form(URI.parse(Purl),ppara)

    res = Net::HTTP.get(URI.parse(Tlogout+sid))

    ret=JSON.parse(pres.body).merge({action: :registed})
    return ret if ret['success']
    return ret.merge({message: 'StationError'})
  end

  def clear_list
    res = Net::HTTP.get(URI.parse(Tlogin))

    sidb=JSON.parse(res)
    sid=sidb["data"]["sid"]
    ppara={api: "SYNO.DownloadStation.Task",
           version: "3",
           method: "list",
          }
    ppara["_sid"]=sid
    pres= Net::HTTP.post_form(URI.parse(Purl),ppara)
    list=JSON.parse(pres.body)

    dpara={api: "SYNO.DownloadStation.Task",
           version: "3",
           method: "delete",
          }
    dpara["_sid"]=sid
    list["data"]["tasks"].each do |task|
      if task["status"]=="finished"
        dpara["id"]=task["id"]
        dres= Net::HTTP.post_form(URI.parse(Purl),dpara)
      end
    end

    res = Net::HTTP.get(URI.parse(Tlogout+sid))

  end

  def send_error_mail(str="至急、直してください",title="異常が発生しています。")
    mail = Mail.new
    options = { 
      address:   ENV['ML_SERVER'],
      port:      587,
      user_name: ENV['ML_USERNAME'],
      password:  ENV['ML_PASSWORD'],
      authentication: :login,
      enable_starttls_auto: true,
    }
    mail.charset = 'utf-8'
    mail.from    ENV['ML_FROM']
    mail.to      ENV['ML_TO']
    mail.subject "[Downloader]"+title
    mail.body    str
    mail.delivery_method(:smtp, options)
    mail.deliver
  end
  
  def call
    clear_list()
    ret=main()
    send_error_mail(ret[:message],ret[:title])
  end

end

if $0 == __FILE__
  Downloader.new.call
end
