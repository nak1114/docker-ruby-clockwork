#!ruby
# -*- coding: utf-8 -*-

require "clockwork"

require './download.rb'

module Clockwork
  handler do |job|
    job.call
  end

  every(8.hour, Downloader.new)

end
