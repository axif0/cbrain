class GroupsController < ApplicationController
  # GET /groups
  # GET /groups.xml
  def index
    @groups = Group.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
  def show
    @group = Group.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.xml
  def new
    @group = Group.new
    @institution_names = Institution.find(:all).map{|i| i.name}
    @manager_names = User.find(:all).select{|u| (u.role == 'admin' || u.role == 'manager') && u.login != 'admin'}.map{|i| i.full_name}
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])
    @institution_names = Institution.find(:all).map{|i| i.name}
    @manager_names = User.find(:all).select{|u| (u.role == 'admin' || u.role == 'manager') && u.login != 'admin'}.map{|i| i.full_name}
  end

  # POST /groups
  # POST /groups.xml
  def create
    params[:group][:institution_id] = Institution.find_by_name(params[:group][:institution_id]).id unless params[:group][:institution_id].blank?
    params[:group][:manager_id] = User.find_by_full_name(params[:group][:manager_id]).id unless params[:group][:manager_id].blank?
    
    @group = Group.new(params[:group])

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Group was successfully created.'
        format.html { redirect_to groups_path }
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        @institution_names = Institution.find(:all).map{|i| i.name}
        format.html { render :action => "new" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update
    @group = Group.find(params[:id])
    params[:group][:institution_id] = Institution.find_by_name(params[:group][:institution_id]).id if params[:group][:institution_id]
    params[:group][:manager_id] = User.find_by_full_name(params[:group][:manager_id]).id if params[:group][:manager_id]
    
    respond_to do |format|
      if @group.update_attributes(params[:group])
        flash[:notice] = 'Group was successfully updated.'
        format.html { redirect_to groups_path }
        format.xml  { head :ok }
      else
         @institution_names = Institution.find(:all).map{|i| i.name}
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
  end
end
