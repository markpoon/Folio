# Requirements
[ "sinatra", "haml", "sass", "redcarpet", "pry", "active_support", "mongoid" ].each { |gem| require gem}
enable :inline_templates
set :public_folder, 'public'
Mongoid.load! "config/mongoid.yml"

enable :sessions
class User
  include Mongoid::Document
  field :email, type: String
  field :salt, type: String
  field :hashed_password, type: String
  
  def password=(pass)
    @password = pass
    self.salt = User.random_string(10) unless self.salt
    self.hashed_password = User.encrypt(@password, self.salt)
  end

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass + salt)
  end

  def self.authenticate(email, pass)
    u = User.find_by(email: email)
    return nil if u.nil?
    return u if User.encrypt(pass, u.salt) == u.hashed_password
    nil
  end

  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    str = ""
    1.upto(len) { |i| str << chars[rand(chars.size-1)] }
    return str
  end  
end

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

class Folio
  include Mongoid::Document
  field :title, type: String, label: :_id
  field :thumbnail, type: String 
  field :updated, type: DateTime, default: nil
  field :created, type: DateTime, default: ->{ Time.now }
  field :tag, type: Array, default: nil
  has_many :contents, dependent: :delete
  validates_presence_of :title, :thumbnail, :contents, :tag
  validates_uniqueness_of :title
end

class Content
  include Mongoid::Document
  field :title, type: String
  field :block, type: String
  belongs_to :folio
  validates_presence_of :title, :block
  validates_uniqueness_of :title
end

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

helpers do
  # SESSIONS #  
  def trim(data) ; proc = Proc.new { |k, v| v.delete_if(&proc) if v.kind_of?(Hash);  v.empty? }; data.delete_if(&proc); end
  def authorized?
    if session[:user]
      return true 
    else 
      status 401 
    end
  end
  def authorize!; redirect '/login' unless authorized?; end  
  def logout!; session[:user] = false; end
  def generate_form(model, obj=nil)
    a = ""
    # gets all field names and generate a dynamic input for each and inputs the obj value if generating a form for edit
    model.classify.constantize.fields.keys[2..model.classify.constantize.fields.keys.count-2].each{|v| a << dynamicinput(v, model+"[#{v}]", obj.nil? ? (nil) : (obj[v])) unless v ==("created"||"updated")}
    # gets the association keys for this model and for each one of them...
    model.classify.constantize.associations.keys.each do |v|
      # check if there the association exists on obj, do 0 to 1 if it exists, or up to the length of that association if it doesn't
      0.upto((defined? obj[v] || obj.nil?) ? (1) : (obj[v].length-1)) do |i|
        a << "<legend>#{model.classify} #{v}</legend><ol>"
        # gets the association keys for this model and generates an input field for it.
        v.classify.constantize.fields.keys[2, 99].each do |x| 
          a << dynamicinput(x, model+"[#{v}_attributes][#{i}][#{x}]", (defined? obj[v][i][x]) ? (obj[v][i][x].to_s) : (nil)) unless x == "folio_id"
        end
        a << "</ol>"
      end
    a << "<input type ='button' value='Add another #{v}' id='addcontent'/>"
    end
    a
  end
  
  def dynamicinput(title, db, v=nil)
     haml :_input, :locals => {:labelname => (title), :db => (db), :value => (v)}
  end
  def tagarray(t)
    t.strip.gsub(/(\^\s\*|\d)/, "").gsub(/\s+/, " ").split(", ")
  end
end

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

# SESSIONS #
get '/login' do  
  haml :login
end

post '/login' do
  if session[:user] = User.authenticate(params[:login], params[:password])
    @user = session[:user]
  else
    status 401
  end
  redirect '/' 
end

get '/logout' do
  logout!
  @user = nil
  redirect '/'
end

get '/register' do
  
end

post '/register' do
  user = User.new
  user.email = params[:email]
  user.password = params[:password]
  user.save!
  redirect "/"
end


get '/folio/' do
  folio = Folio.all
  if folio.nil? then
    status 404
  else
    status 200
    @folio = folio
    haml :index
  end
end


# REST #

get '/folio/new/' do
  haml :newedit
end
post '/folio/:title' do
  authorized?
  if data.nil? then
    status 404
  else
    updated = false
    %w(:title, :tag :content).each do |k| #~#~#~ You need to put what fields to update
      if data.has_key? k
        folio[k] = data[k]
        updated = true
      end
    end
    if updated then
      folio[:updated] = Time.now
    !folio.save ? (status 500) : (status 200)
    end
  end
end

get '/folio/:title' do
  folio = Folio.find_by(title: params[:title])
  if folio nil? then
    status 404
  else
    status 200
    @folio = folio
    haml :show
  end
end

get '/folio/edit/:title' do
  folio = Folio.find_by(title: params[:title])
  if folio nil? then
    status 404
  else
    status 200
    @folio = folio
    haml :newedit
  end
end

# MARKDOWN
# Paragraphs are double line breaks
# ## Heading 2 
# > Blockqoute
# `` or four spaces for code
# * something and #. something for lists.
# [display](url), ![]() for image

put '/folio/:title' do
  authorized?
  data = Folio.find_by(title: params[:title])
  trim data
  if data.nil? or !data.has_key? 'content' then
    status 404
  else
    folio = Folio.new( #~#~#~ add stuff here! remember the comma
      title: data[:title].tr!(' ', '_'),
      updated: Time.now,
      tag: (tagarray data[:tag])   
    ) 
    data[:content].length.each_with_index do |datacontent, i|
      folio[:content][i][:title] = datacontent[i][:title]
      folio[:content][i][:block] = datacontent[i][:block]
    end
    folio.save
    status 200
  end
end
delete '/folio/:title' do
  authorized?
  folio = Folio.find_by(title: params[:title])
  if folio nil? then
    status 404
  else
    note.destroy ? (status 200) : (status 500)
    redirect '/folio/'
  end
end



# INTERFACE #
get "/style.css" do
  content_type 'text/css', :charset => 'utf-8'
  scss :style
end

get "/?" do
  @folio = Folio.desc(:created)
  haml :index
end

__END__

@@layout
!!! 5
%html
  %head
    %title="Theta's Portfolio"
    %link{:href => "/style.css", :rel => "stylesheet"}
    %script{:src => "js/modernizr.js"}
  %body
    %header
      = haml :_nav
      = haml :_search
      
  %container
    = yield
  %footer
    = haml :_login
  %script{:src => "js/right.js"}
  %script{:src => "js/formadder.js"}

@@_nav
.nav
  %a{href: '/'}> &thetasym; 
  %a{href: '/note/'}> Note To Future Self 
  %a{href: '/folio/'}> Portfolio 
  %a{href: 'mailto:markpoon@me.com'}> Contact Me
  
@@_login
- if @user
  %span
    %p
      You are logged in as #{@user.name}
      %a{:href => '/logout'} Logout
- else
  %form.login{:action => "/login", :method => "post"}
    %input#login{:name => "login", :placeholder => "Login", :type => "text"}/
    %input#password{:name => "password", :placeholder => "Password", :type => "password"}/
    %input#loginer{:name => "submit", :type => "submit", :value => "Login"}/
  %a{:href => '/register'} Register
  
@@_register
%form.register{:action => '/register', :method => 'post'}
  dynamicinput('email', 'email')
  dynamicinput('password', 'password')
  %input{:name => 'submit', :type 'submit', :value => 'make new user'}

@@_search
#search
  %form{:action=>"/search", :method=>"post", :id=>"search"}
    %input{:type => "text", :name => "search", :class => "search", :placeholder => "Search Tags"}

@@index
.imagetiles
  - @folio.each do |folio|
    %h1=folio[:title]
    - folio.contents.each do |content|
      = markdown content.block
    .tags  
    - folio.tag.each do |t|
      .tag
        %a{href: "/search/#{t}"}>=t

@@show
%p @folio[:title]
- folio[:content].length.each_with_index do |content, i|
  - markdown.render content[i][:block]
- @folio[:tag].each do |t|
  - tag t
=haml :_admincontrol
  
@@newedit
%form{:action=>"/folio/:title", :method=>"put"}
  %ul
    = generate_form("folio", (@folio ? (@folio) : (nil)))
  %input{:type => 'submit', :value => 'save', :class => 'button'}

@@_input
%li
  %label{:for => labelname}=labelname.capitalize
  %input{:name => db, :value => value}
   
@@_admincontrol
-if authenticated?
  %form{:action => "/folio/:title", :method => "update"}
    %input{:type => 'submit', :value => 'Update', :class => 'button'}
  %form{:action => "/folio/:title", :method => "post"}
    %input{:name=> "_method", :value=>"delete", :type=>"hidden"}
    %input{:type => 'submit', :value => 'Delete', :class => 'button'}
