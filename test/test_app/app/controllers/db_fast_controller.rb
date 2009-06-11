class DbFastController < ApplicationController
  def index
    ActiveRecord::Base.connection.execute("select * from schema_info")
    render :text => "Hello world! #{Time.now}"
  end
end
