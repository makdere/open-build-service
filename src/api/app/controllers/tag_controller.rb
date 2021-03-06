class TagController < ApplicationController
  
  validate_action :tags_by_user_and_object => {:method => :get, :response => :tags}
  validate_action :project_tags => {:method => :get, :response => :tags}
  validate_action :package_tags => {:method => :get, :response => :tags}
  
  #list all available tags as xml list
  def list_xml
    @taglist = Tag.find(:all)
    render :partial => "listxml"
  end
  private :list_xml
  
  def get_tagged_projects_by_user
    begin
      @user = User.get_by_login(params[:user])
      
      @taggings = Tagging.find(:all,
                               :conditions => ["taggable_type = ? AND user_id = ?","DbProject",@user.id])
      @projects_tags = {}
      @taggings.each do |tagging|
        project = DbProject.find(tagging.taggable_id)
        tag = Tag.find(tagging.tag_id)
        @projects_tags[project] = [] if @projects_tags[project] == nil
        @projects_tags[project] <<  tag
      end
      @projects_tags.keys.each do |key|
        @projects_tags[key].sort!{ |a,b| a.name.downcase <=> b.name.downcase }
      end
      @my_type = "project"
      render :partial => "tagged_objects_with_tags"
    

    rescue Exception => error
      render_error :status => 404, :errorcode => 'tag_error',
      :message => error 
    end 
  end
  
  
  def get_tagged_packages_by_user
    begin
      @user = User.get_by_login(params[:user])
      @taggings = Tagging.find(:all,
                               :conditions => ["taggable_type = ? AND user_id = ?","DbPackage",@user.id])
      @packages_tags = {}
# FIXME2.2: this is not filtering hidden projects
      @taggings.each do |tagging|
        package = DbPackage.find(tagging.taggable_id)
        tag = Tag.find(tagging.tag_id)
        @packages_tags[package] = [] if @packages_tags[package] == nil
        @packages_tags[package] <<  tag
      end
      @packages_tags.keys.each do |key|
        @packages_tags[key].sort!{ |a,b| a.name.downcase <=> b.name.downcase }
      end
      @my_type = "package"
      render :partial => "tagged_objects_with_tags"
      
      
    rescue Exception => error
      render_error :status => 404, :errorcode => 'tag_error',
      :message => error 
    end 
  end
  
  
  def get_tags_by_user
    @user = @http_user
    @tags = @user.tags.find(:all, :group => "name")
    @tags
  end
  
  
  def get_projects_by_tag ( do_render=true )
    @tag = params[:tag]      
    @projects = Array.new

     first_run = true

    @tag.split('::').each do |t|
      tag = Tag.find_by_name(t)
      raise TagNotFoundError.new("Tag #{t} not found") unless tag

      unless first_run         
        @projects = @projects & tag.db_projects.find(:all, :group => "name", :order => "name")      
      else
        @projects = tag.db_projects.find(:all, :group => "name", :order => "name")
        first_run = false 
      end
    end

    if do_render
      render :partial => "objects_by_tag"
      return
    end
    return @projects
  end
  
  
  def get_packages_by_tag( do_render=true )
    @tag = params[:tag]
    @packages = Array.new
    
    first_run = true
    
    @tag.split('::').each do |t|
      tag = Tag.find_by_name(t)
      raise TagNotFoundError.new("Tag #{t} not found") unless tag
      
      unless first_run
        @packages = @packages & tag.db_packages.find(:all, :group => "name", :order => "name")
      else
        @packages = tag.db_packages.find(:all, :group => "name", :order => "name")
        first_run = false
      end
    end
    
    if do_render
      render :partial => "objects_by_tag"
      return
    end
    return @packages
  end
  
  
  def get_objects_by_tag
    @projects = get_projects_by_tag( false )
    @packages = get_packages_by_tag( false )
    
    render :partial => "objects_by_tag"     
  end
  
  
  def tags_by_user_and_object
    if request.get?
      if params[:package]
        get_tags_by_user_and_package
      else
        get_tags_by_user_and_project
      end
    elsif request.put?
      update_tags_by_object_and_user
    end
  end
  
  
  def get_tags_by_user_and_project( do_render=true )
    user = User.get_by_login(params[:user])
    @type = "project"
    @name = params[:project]
    @project = DbProject.get_by_name(params[:project])
    
    @tags = @project.tags.find(:all, :order => :name, :conditions => ["taggings.user_id = ?",user.id])
    if do_render
      render :partial => "tags"
    else
      return @tags
    end
  end
  
  
  def get_tags_by_user_and_package( do_render=true  )
    user = User.get_by_login(params[:user])
    @type = "package" 

    @name = params[:package]
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source=false, follow_project_links=false)
    @project = @package.db_project
    
    @tags = @package.tags.find(:all, :order => :name, :conditions => ["taggings.user_id = ?",user.id])
    if do_render
      render :partial => "tags"
    else
      return @tags
    end
  end
  
  
  def most_popular_tags()
  end
  
  
  def most_recent_tags()
  end     
  
  
  def tagcloud 
    allowed_distribution_methods = ['raw', 'linear' , 'logarithmic']
    @limit = params[:limit] or @limit = 100
    @limit = @limit.to_i
    
    @steps = (params[:steps] ||= 6).to_i
    if @steps < 1 or @steps > 100
      render_error :status => 404, :errorcode => 'invalid_value',
        :message => "Invalid value for parameter steps.  (must be 1..100)" 
      return
    end
    
    @distribution_method = (params[:distribution] ||= "logarithmic")
    if not allowed_distribution_methods.include? @distribution_method
      render_error :status => 404, :errorcode => 'invalid_value',
        :message => "Invalid value for parameter distribution.  (distribution=#{@distribution_method})" 
      return
    end
    
    if request.get?
      if params[:user]
        user = User.get_by_login(params[:user])
        tagcloud = Tagcloud.new(:scope => "user", :user => user, :limit => @limit)
      else
        tagcloud = Tagcloud.new(:scope => "global", :limit => @limit)
      end
      
      #get the list of tags
      @tags = tagcloud.get_tags(@distribution_method,@steps)
      raise ArgumentError.new( "tag-cloud generation failed." ) if @tags.nil?
      
      render :partial => "tagcloud"
      
    elsif request.post?
      #The request-data includes a collection of objects (projects and
      #packages atm.). Based on this objects the tagcloud will be calculated.
      request_data = request.raw_post
      
      collection = ActiveXML::XMLNode.new( request_data )
      
      #get the projects
      projects =[]
      collection.each_project do |project|
        proj = DbProject.get_by_name(project.name)
        
        projects << proj
      end
      
      #get the packages
      packages = []
      collection.each_package do |package|
        project = DbProject.get_by_name(package.project)
        
        pack = DbPackage.get_by_project_and_name( project.name, package.name, use_source=false, follow_project_links=false )
        
        packages << pack
      end
      
      objects = projects + packages
      
      #creating the tagcloud
      tagcloud = Tagcloud.new(:scope => 'by_given_objects', :objects => objects, :limit => @limit)
      
      #get the tags and the tag-sizes or counts
      @tags = tagcloud.get_tags(@distribution_method, @steps)

      render :partial => 'tagcloud'
    end
  end
  
  
  #TODO helper function, delete me
  def get_taglist
    tags = Tag.find(:all, :order => :name)
    return tags
  end
  
  def project_tags 
    #get project name from the URL
    project_name = params[:project]
    if request.get?
      @project = DbProject.get_by_name( project_name )
      logger.debug "GET REQUEST for project_tags. User: #{@user}"
      @type = "project" 
      @name = params[:project]
      @tags = @project.tags.find(:all, :group => "name", :order => :name)
      render :partial => "tags"
      
    elsif request.put?
      
      @project = DbProject.get_by_name( project_name )
      logger.debug "Put REQUEST for project_tags. User: #{@http_user.login}" 
      
      #TODO Permission needed!
      
      if !@http_user 
        logger.debug "No user logged in."
        render_error( :message => "No user logged in.", :status => 403 )
        return
      else
        @tagCreator = @http_user
      end
      #get the taglist xml from the put request
      request_data = request.raw_post
      #taglistXML = "<the whole xml/>"
      @taglistXML = request_data
      
      #update_tags_by_project_and_user(request_data)
      
      @tags =  taglistXML_to_tags(request_data)
      
      save_tags(@project, @tagCreator, @tags)
      
      logger.debug "PUT REQUEST for project_tags."     
      render :nothing => true, :status => 200
    end 
  end
  
  
  def package_tags
    
    project_name = params[:project]
    package_name = params[:package]
    if request.get?
      @project = DbProject.get_by_name( project_name )
      @package = DbPackage.find_by_db_project_id_and_name( @project.id, package_name )
      
      logger.debug "[TAG:] GET REQUEST for package_tags. User: #{@user}"
      
      @type = "package" 
      @tags = @package.tags.find(:all, :group => "name")
      render :partial => "tags"
      
    elsif request.put?
      logger.debug "[TAG:] PUT REQUEST for package_tags."
      @project = DbProject.get_by_name( project_name )
      @package = DbPackage.find_by_db_project_id_and_name( @project.id, package_name )
      
      #TODO Permission needed!
      
      if !@http_user 
        logger.debug "No user logged in."
        render_error( :message => "No user logged in.", :status => 403 )
        return
      else
        @tagCreator = @http_user
      end
      #get the taglist xml from the put request
      request_data = request.raw_post
      #taglistXML = "<the whole xml/>"
      @taglistXML = request_data
      
      @tags =  taglistXML_to_tags(request_data)
      
      save_tags(@package, @tagCreator, @tags)
      
      render :nothing => true, :status => 200
      
    end
  end
  
  
  def update_tags_by_object_and_user
    @user = User.get_by_login(params[:user])
    unless @user == @http_user
      render_error :status => 403, :errorcode => 'permission_denied',
        :message => "Editing tags for another user than the logged on user is not allowed."
      return
    end

    @project = DbProject.get_by_name(params[:project])
    
    tags, unsaved_tags = taglistXML_to_tags(request.raw_post)
    
    tag_hash = {}
    tags.each do |tag|
      tag_hash[tag.name] = ""
    end
    logger.debug "[TAG:] Hash of new tags: #{@tag_hash.inspect}"
    
    if params[:package]
      logger.debug "[TAG:] Package selected"
      @package = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source=false, follow_project_links=false)
      
      old_tags = get_tags_by_user_and_package( false )
      old_tags.each do |old_tag|
        unless tag_hash.has_key? old_tag.name
          Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@package.id} AND taggable_type = 'DbPackage' AND tag_id = #{old_tag.id}")
        end
      end
      save_tags(@package,@user,tags)
    else
      logger.debug "[TAG:] Project selected"
      old_tags = get_tags_by_user_and_project( false )
      old_tags.each do |old_tag|
        unless tag_hash.has_key? old_tag.name
          Tagging.delete_all("user_id = #{@user.id} AND taggable_id = #{@project.id} AND taggable_type = 'DbProject' AND tag_id = #{old_tag.id}")
        end
      end
      save_tags(@project,@user,tags)
    end    
    
    if not unsaved_tags
      render :nothing => true, :status => 200
    else  
      error = "[TAG:] There are rejected Tags: #{unsaved_tags.inspect}"
      logger.debug "#{error}"
      #need exception handling in the tag client
      render_error :status => 400, :errorcode => 'tagcreation_error',
      :message => error 
    end
  end
  private :update_tags_by_object_and_user
  
  
  def taglistXML_to_tags(taglistXML)
    
    taglist = []
    
    xml = REXML::Document.new(taglistXML)
    
    xml.root.get_elements("tag").each do  |tag| 
      taglist << tag.attributes.get_attribute("name").value
    end
    
    #make tag objects
    tags = []
    taglist.each do |tagname|
      begin
        tags << s_to_tag(tagname)
      
      rescue RuntimeError => error
        @unsaved_tags ||= []
        @unsaved_tags << tagname
        logger.debug "[TAG:] #{error}" 
      end      
    end 
    
    return tags, @unsaved_tags
  end
  private :taglistXML_to_tags
  
  
  def save_tags(object, tagCreator, tags)
    if tags.kind_of? Tag then
      tags = [tags]
    end  
    tags.each do |tag|
      begin
        create_relationship(object, tagCreator, tag)
      rescue ActiveRecord::StatementInvalid
        logger.debug "The relationship #{object.name} - #{tag.name} - #{tagCreator.login} already exist."
      end  
    end      
  end
  private :save_tags
  
  
  #create an entry in the join table (taggings) if necessary
  def create_relationship(object, tagCreator, tag)
    Tagging.transaction do
        @jointable = Tagging.new()
        object.taggings << @jointable
        tagCreator.taggings << @jointable
        tag.taggings << @jointable
        @jointable.save
    end  
  end
  private :create_relationship
  
  
  #get the tag as object
  def s_to_tag(tagname)
    tag = Tag.find_or_create_by_name(tagname)
    raise RuntimeError.new( "Tag #{tagname} could not be saved. ERROR: #{tag.errors[:name]}" ) if not tag.valid?
    return tag
  end
  private :s_to_tag
  
  
  def tag_error(params)
    render_error :status => 404, :errorcode => 'unknown_tag',
    :message => "Unknown tag #{params[:tag]}" 
  end
  private :tag_error
  
end
