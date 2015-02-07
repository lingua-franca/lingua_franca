class ApplicationController < LinguaFrancaApplicationController
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :set_translator
  helper_method :current_user

  def home
  	@posts = Blog.all
  	@new_post = Blog.new
  end

  def login
  	if params[:user] && params[:user][:name] && session[:current_user].blank?
  		name = params[:user][:name]
  		user = User.where(:name => name).limit(1).first
  		if user.nil?
  			User.create(:name => name)
  			user = User.where(:name => name).limit(1).first
  		end
  		session[:current_user] = user.id
  	end
  	redirect_to :home
  end

  def logout
  	session[:current_user] = nil
  	redirect_to :home
  end

  def current_user
    return (@current_user ||= nil) if @current_user.present?
    return nil if session[:current_user].blank?
    if session[:current_user].is_a?(Hash)
    	session[:current_user] = session[:current_user]['id']
    end
    @current_user ||= User.find_by_id(session[:current_user])
    if @current_user.nil?
    	session[:current_user] = nil
    end
    @current_user
  end

  def translate_toggle
  	puts params.to_json.to_s
  	session[:translating] = params[:start_translating].present?
  	redirect_to (params[:start_translating].present? ? :translations_index : :home)
  end

  def save_post
  	if current_user && params[:blog] && params[:blog][:title].present? && params[:blog][:content].present?
  		if params[:blog][:id].present?
  			post = Blog.find(params[:blog][:id])
  			post.update_attributes(user: current_user, title: params[:blog][:title], content: params[:blog][:content])
  		else
  			Blog.create(user: current_user, title: params[:blog][:title], content: params[:blog][:content])
  		end
  	end
  	redirect_to :home
  end

  def translate_post
  	if !current_user.present? | !params[:id].present?
  		return redirect_to :home
  	end
  		
	@post = Blog.find(params[:id])
	if @post.locale == I18n.locale.to_s
		# should really be doing a 404
		return redirect_to :home
	end
  end

  private
    def set_translator
      current_user.translating = session[:translating] if current_user.present?
      I18n.config.translator = current_user
    end
  
end
