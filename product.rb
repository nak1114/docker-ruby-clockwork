# -*- coding: utf-8 -*-
require "active_record"
class Product < ActiveRecord::Base
  belongs_to :status
  def site
    self.url.slice(%r!^http?://[^/]/!)
  end
  def self.at_site(site)
    where('url like ?',sanitize_sql_like(site)+'%')
  end
  def self.search(keyword)
    return all if keyword == '' or keyword==nil
    k='%'+sanitize_sql_like(keyword)+'%'
    where('`url` like ? or `name` like ? or `rename` like ?',k,k,k)
  end
  def self.sfilter(status)
    return all unless status
    where(status_id: status)
  end
  def sname
    self.status.name
  end
  def as_json(options = {})
     options[:methods]||=[]
     options[:methods] << :sname
     super(options)
  end

end
