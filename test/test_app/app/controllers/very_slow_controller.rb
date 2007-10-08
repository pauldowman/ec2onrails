class VerySlowController < ApplicationController
  def index
    sleep 2
    render :text => 'Hello world!'
  end
end
