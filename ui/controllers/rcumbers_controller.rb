require File.expand_path(File.dirname(__FILE__) + '/../helpers/rcumbers_helper')

class RcumbersController < ApplicationController

  before_filter :get_rcumber, :except => [:rcumber_icon]
  
  layout 'rcumbers'
  include RcumbersHelper
  
  def index
    get_profiles
    if params[:demos] == "true"
      @rcumbers = Rcumber.demos
    else
      @rcumbers = Rcumber.all
    end
    @rcumber = @rcumbers.first ## TODO: Remove me
  end
  def get_rcumber
    id = params[:rcumber_id] ? params[:rcumber_id] : params[:id]
    if params[:demos] == "true"
      @rcumber = Rcumber.find_demo(id)
    else
      @rcumber = Rcumber.find(id)
    end
    @rcumber.profile=params[:rcumber][:profile] rescue nil
  end
    
  def show
    get_rcumber
    if @rcumber
      render :action => 'show'
    else
      flash.now[:error] = "Could not locate Cucumber test for #{params[:id].inspect}"
      @rcumbers = Rcumber.all
      render :action => 'index'
    end
  end
  
  def run
    get_rcumber
    @rcumber.run 
    # Process.detach(p)
    flash.now[:notice] = "Cucumber test completed." if @rcumber.state == :passing
    flash.now[:error] = "Cucumber test completed." if @rcumber.state == :failing
    params[:selected_tab] = 'run'
    render :action => 'show'
  end
  def run_many
    uids=params[:uids]
    uids.each do |uid|
      @rcumber = (params[:demos] && params[:demos] == "true") ? Rcumber.find_demo(uid) : Rcumber.find(uid)
      @rcumber.profile=params[:rcumber][:profile] rescue nil
      @rcumber.run
    end
    @rcumbers=Rcumber.all
    redirect_to :action=>:index
  end
  
  def runall
    Rcumber.all.each do |c|
      c.profile=params[:rcumber][:profile] rescue nil
      c.run
    end

    flash.now[:notice] = "Cucumber test just completed."
    @rcumbers = Rcumber.all
    render :action => 'index'
  end
  
  def new
    if request.post?
      begin
        do_save(params[:rcumber])
        render :action => 'edit'
      rescue Exception => e
        @rcumber = Rcumber.new
        flash.now[:error] = e.to_s
      end
    elsif request.get?
      @rcumber = Rcumber.new
      render :action => 'new'
    end
  end
  
  def edit
    get_rcumber
    raise "Could not find cucumber file for #{params[:id]}" if @rcumber.nil?
  end
  
  def update
    get_rcumber
    if params[:rcumber][:raw_content].empty?
      flash.now[:error] = "Please don't try to pickle an empty cuke!."
      render :action => 'edit'
    else
      @rcumber.raw_content = params[:rcumber][:raw_content]
      @rcumber.save
      flash.now[:notice] = "Cucumber was pickled!"
      render :action => 'show'
    end
  end
  
  def destroy
    get_rcumber
    @rcumber.destroy
    @rcumbers = Rcumber.all
    render :action => 'index'
  end
  
  # don't want to include any filters inside the application chain - might create errors
  if respond_to? :filter_chain
    filters = filter_chain.collect do |f|
      if f.respond_to? :filter
        # rails 2.0
        f.filter
      elsif f.respond_to? :method
        # rails 2.1
        f.method
      else
        fail "Unknown filter class."
      end
    end
    skip_filter filters
  end
  
  view_path = File.join(File.dirname(__FILE__), '..', 'views')
  if public_methods.include? 'append_view_path' # rails 2.1+
    self.append_view_path view_path
  elsif public_methods.include? "view_paths"   # rails 2.0+
    self.view_paths << view_path
  else                                      # rails <2.0
    self.template_root = view_path
  end

  private
  
    def do_save(rcumber)
      raise "Must supply a base filename"  if rcumber[:path].empty?
      raise "Path can only contain alphanumerics and underscores" unless (rcumber[:path] =~ /^[a-z_]+$/)
      raise "Must supply a feature name"  if rcumber[:name].empty?
      @rcumber = Rcumber.create_with_relative_path(params[:rcumber][:path])
      raise "Are you sure you have Cucumber installed? We can't seem to find the directory #{File.dirname(@rcumber.path)}" unless File.exist?(File.dirname(@rcumber.path))
      @rcumber.raw_content = "Feature: #{params[:rcumber][:name]}"
      @rcumber.save
      flash.now[:notice] = "Cucumber was pickled!"
      redirect_to :controller => 'rcumbers', :action => 'edit', :id => @rcumber.uid
    end
    def get_profiles
      @profiles = Rcumber.profiles
    end
end
