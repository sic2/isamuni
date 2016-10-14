class AdminController < ApplicationController
  layout "user_area"
  before_action :require_admin

  def index
  		@pages = Page.page(params[:page_page])
      @users = User.page(params[:user_page])
      @events = Event.page(params[:event_page]).order('starts_at DESC')
      @posts = Post.page(params[:post_page]).order('created_at DESC')
	end

  def make_page_inactive
    page = Page.find(params[:pageid])
    page.active = false
    page.save
  end

  def make_page_active
    page = Page.find(params[:pageid])
    page.active = true
    page.save
  end

  def delete_page
    Page.delete(params[:pageid])
  end

  def make_post_inactive
    post = Post.find(params[:postid])
    post.show = false
    post.save
  end

  def make_post_active
    post = Post.find(params[:postid])
    post.show = true
    post.save
  end

  def ban_user
    user = User.find(params[:userid])
    user.banned = true
    user.save
  end

  def unban_user
    user = User.find(params[:userid])
    user.banned = false
    user.save
  end

  def require_admin
    unless current_user != nil && current_user.is_admin?
      render :file => "public/401.html", :status => :unauthorized
    end
  end

end
