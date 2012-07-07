# Requirements
[ "sinatra", "haml", "sass", "redcarpet", "pry", "active_support", "mongoid", "coffee-script" ].each { |gem| require gem}
enable :inline_templates
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

class Quote
  include Mongoid::Document
  field :quotation, type: String
  field :author, type: String
  validates_presence_of :quotation, :author
  validates_uniqueness_of :quotation
end

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

helpers do
  # SESSIONS #  
  def trim(data); proc = Proc.new { |k, v| v.delete_if(&proc) if v.kind_of?(Hash);  v.empty? }; data.delete_if(&proc); end
  def authorized?; session[:user] ? (return true) : (status 403); end
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
  def tagarray(t); t.strip.gsub(/(\^\s\*|\d)/, "").gsub(/\s+/, " ").split(", "); end
  def search(pattern="")
    Folio.in('tag' => pattern.strip.gsub(/(\^\s\*|\d)/, "").gsub(/\s+/, " ").split(", "))
  end
end


#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

before do
  if session[:user] then @user = session[:user] end
end

post '/search' do
  @folio = search params[:search]
  haml :'folioindex'
end

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
    haml :folioindex
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
  if folio.nil? then
    status 404
  else
    status 200
    @folio = folio
    haml :show
  end
end

get '/folio/edit/:title' do
  folio = Folio.find_by(title: params[:title])
  if folio.nil? then
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
      title: data[:title].downcase.gsub(/\s/, '_'),
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
  if folio.nil? then
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

get '/js/run.js' do
  content_type "text/javascript", :charset => 'utf-8'
  coffee :run
end

get "/?" do
 
  d = Quote.count-1
  quote = Quote.desc[rand 0..d]
  if quote.nil? then
    status 404
  else
    status 200
    @quote = quote
    haml :index
  end
end

__END__

@@layout
!!! 5
%html
  %head
    %title="Theta"
    %link{:href => "/style.css", :rel => "stylesheet"}
    %script{:src => "/js/modernizr.js"}
  %body
    %header
      = haml :_nav
  %container
    = yield
  %footer
    #footer= haml :_login
  %script{:src => "/js/right.js"}
  %script{:src => "/js/run.js"}

@@_nav
.nav
  %a{href: '/'}> &thetasym; 
  %a{href: '/folio/'}> Portfolio 
  %a{href: 'mailto:markpoon@me.com'}> Contact Me
  #loginimage
    %img{src: "/images/login.png"}
  = haml :_search
  
@@_login
- if @user
  %span
    %p
      You are logged in as #{@user.email}
      %a{:href => '/logout'} Logout
- else
  %form.login{:action => "/login", :method => "post"}
    %input#login{:name => "login", :placeholder => "Login", :type => "text"}/
    %input#password{:name => "password", :placeholder => "Password", :type => "password"}/
    %input#loginer{:name => "submit", :type => "submit", :value => "Login"}/

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
.row
  .twelvecol
    %h1=@quote.quotation
    %p{align: "right"}=@quote.author
.row
  .fourcol
    = markdown File.read("./views/index/bio.md")
  .fourcol
    = markdown File.read("./views/index/purpose.md")
  .fourcol.last
    = markdown File.read("./views/index/tools.md")

@@folioindex
.imagetiles
  -@folio.each do |folio|
    %figure
      %a{href: "/folio/#{folio[:title]}"}>
        %img{src: folio[:thumbnail]}
      %figcaption
        %table{align: "right"}
          %tr
            %td{width: "100%"}
              %a{href: "/folio/#{folio[:title]}"}>
                %h2=folio[:title].humanize.titlecase
            - folio.tag.each do |t|      
              %td
                .tag
                  %a{href: "/search/#{t}"}>=t

@@show
%br
.row
  %table
    %tr
      %td
        %h2=@folio[:title].humanize.titlecase
      - @folio.tag.each do |t|      
        %td
          .tag
            %a{href: "/search/#{t}"}>=t
.row
  - @folio.contents.each do |content|
    = markdown content.block
=haml :_admincontrol
  
@@newedit
%form{:action=>"/folio/:title", :method=>"put"}
  %ul
    = generate_form("folio", @folio)
  %input{:type => 'submit', :value => 'save', :class => 'button'}

@@_input
%li
  %label{:for => labelname}=labelname.capitalize
  %input{:name => db, :value => value}
   
@@_admincontrol
.row
  .twelvecol
    -if authorized?
      %form{:action => "/folio/edit/#{@folio.title}", :method => "update"}
        %input{:type => 'submit', :value => 'Update', :class => 'button'}
      %form{:action => "/folio/#{@folio.title}", :method => "post"}
        %input{:name=> "_method", :value=>"delete", :type=>"hidden"}
        %input{:type => 'submit', :value => 'Delete', :class => 'button'}
