
module IndepthTimetable
  module IndepthDataPalettesController
    def self.included(base)
      base.instance_eval do
        alias_method_chain :index, :indepth
      end
    end

    def index_with_indepth
      @user = current_user
      @config = Configuration.available_modules
      @employee = @user.employee_record if ["#{t('admin')}","#{t('employee_text')}"].include?(@user.role_name)
      if @user.student?
        @student = Student.first(:conditions => ["admission_no LIKE BINARY(?)", @user.username])
      end
      if @user.parent?
        session[:student_id]=params[:id].present?? params[:id] : @user.guardian_entry.current_ward_id
        Fedena.present_student_id=session[:student_id]
        @student=@user.guardian_entry.current_ward
        @students=@student.siblings.select{|g| g.immediate_contact_id=@user.guardian_entry.id}
      end
      @first_time_login = Configuration.get_config_value('FirstTimeLoginEnable')

      @user_palettes = current_user.own_palettes
      @today = FedenaTimeSet.current_time_to_local_time(Time.now).to_date
      # @cur_date = Date.today
      @cur_date = @today
      render 'index_temp'
    end


  end

end