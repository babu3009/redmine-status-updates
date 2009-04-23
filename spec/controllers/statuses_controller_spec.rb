require File.dirname(__FILE__) + '/../spec_helper'

describe StatusesController, "#index without permission" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => false)
    User.stub!(:current).and_return(@current_user)
  end
  
  it "should not be successful" do
    get :index, :foo => true
    response.should_not be_success
  end

  it "should render the 403 template" do
    get :index
    response.should render_template('common/403')
  end
end

describe StatusesController, "#index" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
    Status.stub!(:recent_updates_for)
  end
  
  it "should be successful" do
    get :index, :id => @project.id
    response.should be_success
  end

  it "should render the index template" do
    get :index, :id => @project.id
    response.should render_template('index')
  end

  it "should assign Statuses for the project" do
    statuses = []
    5.times do
      statuses << mock_model(Status)
    end
    Status.should_receive(:recent_updates_for).with(@project).and_return(statuses)

    get :index, :id => @project.id
    assigns[:statuses].should eql(statuses)
  end


end


describe StatusesController, "#index for all projects" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    controller.stub!(:find_project).and_return(true)
    controller.stub!(:project).and_return(nil)
    Status.stub!(:recent_updates_for)
  end
  
  it "should be successful" do
    get :index
    response.should be_success
  end

  it "should render the index template" do
    get :index
    response.should render_template('index')
  end

  it "should assign Statuses for all the projects" do
    statuses = []
    5.times do
      statuses << mock_model(Status)
    end
    Status.should_receive(:recent_updates_for).with(nil).and_return(statuses)

    get :index
    assigns[:statuses].should eql(statuses)
  end

  it 'should only show Statuses for projects the user is a member of' do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    @current_user
  end
end

describe StatusesController, "#create without permission" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => false)
    User.stub!(:current).and_return(@current_user)
  end
  
  it "should not be successful" do
    post :create, :status => {}
    response.should_not be_success
  end

  it "should render the 403 template" do
    post :create, :status => {}
    response.should render_template('common/403')
  end
end

describe StatusesController, "#create" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true, :name => 'Test user', :pref => {})
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
  end

  it 'should redirect to the index' do
    post :create, :status => {:message => "This is a test"}, :id => @project.id
    response.should be_redirect
    response.should redirect_to(:action => 'index', :id => @project.id)
  end

  it 'should save a new Status' do
    status = mock_model(Status)
    status.should_receive(:user_id=).with(@current_user.id)
    status.should_receive(:project_id=).with(@project.id)
    status.should_receive(:save).and_return(true)
    Status.should_receive(:new).and_return(status)
    
    post :create, :status => {:message => "This is a test"}, :id => @project.id
  end
end

describe StatusesController, "#create from cross project" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(true)
    controller.stub!(:project).and_return(nil)
    Project.stub!(:find).with(@project.id).and_return(@project)
  end

  it 'should redirect to the index' do
    status = mock_model(Status, :project => nil, :user_id= => nil, :project_id= => nil, :save => true)
    Status.should_receive(:new).and_return(status)

    post :create, :status => {:message => "This is a test", :project_id => @project.id}
    response.should be_redirect
    response.should redirect_to(:action => 'index', :id => nil)
  end

  it 'should save a new Status for the project' do
    status = mock_model(Status)
    status.should_receive(:user_id=).with(@current_user.id)
    status.should_receive(:project_id=).with(@project.id)
    status.should_receive(:save).and_return(true)
    Status.should_receive(:new).and_return(status)
    
    post :create, :status => {:message => "This is a test", :project_id => @project.id}
  end

  it 'should not save a Status when the user isnt a member of the project' do
    @protected_project = mock_model(Project)
    Project.should_receive(:find).with(@protected_project.id).and_return(@protected_project)
    @current_user.should_receive(:allowed_to?).with(:create_statuses, @protected_project).and_return(false)
    status = mock_model(Status, :user_id= => nil)
    status.should_receive(:project_id=).with(nil)
    status.should_receive(:save).and_return(false)
    Status.should_receive(:new).and_return(status)
    
    post :create, :status => {:message => "This is a test of posting to a different project", :project_id => @protected_project.id}
  end
end

describe StatusesController, "#tagged" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
    Status.stub!(:recently_tagged_with)
  end
  
  it "should be successful" do
    get :tagged, :id => @project.id, :tag => "test"
    response.should be_success
  end

  it "should render the tagged template" do
    get :tagged, :id => @project.id, :tag => "test"
    response.should render_template('tagged')
  end

  it "should assign Statuses for the project matching the tag" do
    statuses = []
    5.times do
      statuses << mock_model(Status, :message => "This is a #test")
    end
    Status.should_receive(:recently_tagged_with).with('test', @project).and_return(statuses)

    get :tagged, :id => @project.id, :tag => "test"
    assigns[:statuses].should eql(statuses)
  end

end

describe StatusesController, "#tag_cloud" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
    Status.stub!(:tag_cloud)
  end
  
  it "should be successful" do
    get :tag_cloud, :id => @project.id
    response.should be_success
  end

  it "should render the tag_cloud template" do
    get :tag_cloud, :id => @project.id
    response.should render_template('tag_cloud')
  end

  it 'should assign the tags for the view' do
    Status.should_receive(:tag_cloud).and_return([])
    get :tag_cloud, :id => @project.id
    assigns[:tags].should_not be_nil
  end
end



describe StatusesController, "#search without permission" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => false)
    User.stub!(:current).and_return(@current_user)
  end
  
  it "should not be successful" do
    get :search
    response.should_not be_success
  end

  it "should render the 403 template" do
    get :search
    response.should render_template('common/403')
  end
end

describe StatusesController, "#search with no term" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
  end
  
  it "should be successful" do
    get :search, :id => @project.id
    response.should be_success
  end

  it "should render the search template" do
    get :search, :id => @project.id
    response.should render_template('search')
  end

  it "should not assign any Statuses" do
    get :search, :id => @project.id
    assigns[:statuses].should be_nil
  end

  it 'should not assign the term' do
    get :search, :id => @project.id
    assigns[:term].should be_blank
  end
end

describe StatusesController, "#search with term" do
  before(:each) do
    @current_user = mock_model(User, :admin? => false, :logged? => true, :language => :en, :allowed_to? => true)
    User.stub!(:current).and_return(@current_user)

    @project = mock_model(Project, :identifier => 'test-project', :id => 42)
    controller.stub!(:find_project).and_return(@project)
    controller.stub!(:project).and_return(@project)
  end
  
  it "should be successful" do
    get :search, :id => @project.id, :q => 'term'
    response.should be_success
  end

  it "should render the search template" do
    get :search, :id => @project.id, :q => 'term'
    response.should render_template('search')
  end

  it "should assign Statuses for the project" do
    statuses = []
    5.times do
      statuses << mock_model(Status)
    end
    Status.should_receive(:search).with('term', @project).and_return(statuses)

    get :search, :id => @project.id, :q => 'term'
    assigns[:statuses].should eql(statuses)
  end

  it 'should assign the term' do
    get :search, :id => @project.id, :q => 'term'
    assigns[:term].should eql('term')
  end
end
