# -*- coding: utf-8 -*-
require "active_record"
class Status < ActiveRecord::Base
  has_many :putducts
end
