class FastController < ApplicationController
  def index
    render :text => "Hello world! #{Time.now}"
  end
end
