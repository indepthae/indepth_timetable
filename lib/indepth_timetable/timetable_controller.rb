
module IndepthTimetable
  module IndepthTimetableController
    def self.included(base)
      base.instance_eval do

        alias_method_chain :update_timetable_view, :indepth
        alias_method_chain :timetable_pdf, :indepth
        alias_method_chain :update_student_tt, :indepth
        alias_method_chain :student_view, :indepth
        alias_method_chain :update_teacher_tt, :indepth

      end
    end

    def update_timetable_view_with_indepth
      if params[:batch_id].present?
        @timetable=Timetable.find(params[:timetable_id])
        @batch = Batch.find(params[:batch_id])
        tte_from_batch_and_tt(@timetable.id)
        render :update do |page|
          page.replace_html "timetable_view", :partial => "indepth_timetable/view_timetable"
        end
      else
        render :update do |page|
          page.replace_html "timetable_view", :text => "<p class='flash-msg'> #{t('select_one_batch')}</p>"
        end
      end
    end

    def timetable_pdf_with_indepth
      @tt=Timetable.find(params[:timetable_id])
      @batch = Batch.find(params[:batch_id]) if params[:batch_id].present?
      @batch = Student.find(params[:student_id],:include=>:batch).batch if params[:student_id].present?
      @config_value = Configuration.get_config_value('TimetablePdfSetting') || "1"
      tte_from_batch_and_tt(@tt.id)
      @classtimingsets = @class_timing_sets.map {|x| x.class_timing_set }
      @classtimingsets_count = @class_timing_sets.uniq.length
      @class_timing_counts = Hash.new
      @classtimingsets.map {|x| @class_timing_counts[x.id] = {:breaks => x.class_timings.select{|y| y.is_break}.length, :periods => x.class_timings.select{|y| !y.is_break}.length}}
      @max_period_count = @class_timing_counts.values.collect{|x| x[:periods] }.max
      @zoom = @max_period_count > 14 ? 0.9 : 1

      render :pdf => 'indepth_timetable/timetable_pdf', #:show_as_html => true,
             :orientation => 'Landscape',:margin =>{:top=>5,:bottom=>5,:left=>5,:right=>5}, :zoom=> @zoom,
             :header => {:html => { :content=> ''}}, :footer => {:html => { :template=> 'layouts/pdf_footer.html'}}
    end

    def student_view_with_indepth
      @student = Student.find(params[:id])
      @batch=@student.batch
      if @batch.weekday_set_id.present?
        timetable_ids=@batch.timetable_entries.collect(&:timetable_id).uniq
        @timetables=Timetable.find(timetable_ids,:order => "start_date DESC")
        @current=Timetable.find(:first, :conditions => ["timetables.start_date <= ? AND timetables.end_date >= ? and id IN (?)", @local_tzone_time.to_date, @local_tzone_time.to_date, timetable_ids])
        @timetable_entries = Hash.new { |l, k| l[k] = Hash.new(&l.default_proc) }
        unless @current.nil?
          @class_timing_sets=TimeTableClassTiming.find_by_batch_id_and_timetable_id(@batch.try(:id), @current.try(:id)).time_table_class_timing_sets(:joins=>{:class_timing_set=>:class_timings})
          #        @entries=@current.timetable_entries.find(:all, :conditions => {:batch_id => @batch.id, :class_timing_id => @class_timings})
          @entries=TimetableEntry.find(:all,:conditions=>{:batch_id=>@batch.id,:timetable_id=>@current.id},:include=>[:entry,:employees,:timetable_swaps])
          @all_timetable_entries = @entries.select { |s| s.class_timing.is_deleted==false }
          #        @all_weekdays = weekday_arrangers(@all_timetable_entries.collect(&:weekday_id).uniq)
          @all_weekdays = weekday_arrangers(@class_timing_sets.collect(&:weekday_id).uniq)
          #        @all_classtimings = @all_timetable_entries.collect(&:class_timing).uniq.sort! { |a, b| a.start_time <=> b.start_time }
          @all_teachers = @all_timetable_entries.collect(&:employees).flatten.uniq
          @all_timetable_entries.each do |tt|
            @timetable_entries[tt.weekday_id][tt.class_timing_id] = tt
          end
        end
      else
        flash[:notice] = t('timetable_not_set')
        redirect_to :controller => 'user', :action => 'dashboard'
      end
      render 'indepth_timetable/student_view'
    end

    def update_student_tt_with_indepth
      @student = Student.find(params[:id])
      @batch=@student.batch
      @all_timetable_entries = Array.new
      if params[:timetable_id].nil?
        @current=Timetable.find(:first, :conditions => ["timetables.start_date <= ? AND timetables.end_date >= ?", @local_tzone_time.to_date, @local_tzone_time.to_date])
      else
        if params[:timetable_id]==""
          render :update do |page|
            page.replace_html "box", :text => ""
          end
          return
        else
          @current=Timetable.find(params[:timetable_id])
        end
      end
      @timetable_entries = Hash.new { |l, k| l[k] = Hash.new(&l.default_proc) }
      unless @current.nil?
        ttct = TimeTableClassTiming.find_by_batch_id_and_timetable_id(@batch.try(:id), @current.try(:id))
        if ttct.present?
          @class_timing_sets=TimeTableClassTiming.find_by_batch_id_and_timetable_id(@batch.try(:id), @current.try(:id)).time_table_class_timing_sets(:joins=>{:class_timing_set=>:class_timings})
          #        @entries=@current.timetable_entries.find(:all, :conditions => {:batch_id => @batch.id, :class_timing_id => @class_timings})
          @entries=TimetableEntry.find(:all,:conditions=>{:batch_id=>@batch.id,:timetable_id=>@current.id},:include=>[:entry,:employees,:timetable_swaps])
          @all_timetable_entries = @entries.select { |s| s.class_timing.is_deleted==false }
          @all_weekdays = weekday_arrangers(@all_timetable_entries.collect(&:weekday_id).uniq.sort)
          #        @all_classtimings = @all_timetable_entries.collect(&:class_timing).uniq.sort! { |a, b| a.start_time <=> b.start_time }
          @all_teachers = @all_timetable_entries.collect(&:employee).uniq
          @all_timetable_entries.each do |tt|
            @timetable_entries[tt.weekday_id][tt.class_timing_id] = tt
          end
        end
      end

      render :update do |page|
        page.replace_html "time_table", :partial => "indepth_timetable/student_timetable"
      end
    end

    def update_teacher_tt_with_indepth
      if params[:timetable_id].nil?
        @current=Timetable.find(:first, :conditions => ["timetables.start_date <= ? AND timetables.end_date >= ?", @local_tzone_time.to_date, @local_tzone_time.to_date])
      else
        if params[:timetable_id]==""
          render :update do |page|
            page.replace_html "timetable_view", :text => ""
          end
          return
        else
          @current=Timetable.find(params[:timetable_id],:include => :timetable_entries)
        end
      end
      @timetable_entries = Hash.new { |l, k| l[k] = Hash.new(&l.default_proc) }
      @all_timetable_entries = @current.timetable_entries.all(:include=>[:employees,:entry],
                                                              :conditions => ["ct.is_deleted = ? and b.is_active = ?",false,true],
                                                              :joins => "LEFT OUTER JOIN batches b on timetable_entries.batch_id=b.id and b.is_active=1
                 LEFT OUTER JOIN class_timings ct on ct.id=timetable_entries.class_timing_id and ct.is_deleted=0")
      @all_teachers = @all_timetable_entries.collect { |x| x.employees }.flatten.uniq
      @all_subjects = @all_timetable_entries.collect { |x| x.assigned_subjects([:batch]) }.flatten.uniq
      @all_subjects.each do |sub|
        unless sub.elective_group.nil?
          elective_teachers = sub.elective_group.subjects.collect(&:employees).flatten
          @all_teachers+=elective_teachers
        end
      end
      @all_teachers.uniq!
      if @all_teachers.present?
        @employee = @all_teachers.first
        employee_tt_builder
      end
      render :update do |page|
        page.replace_html "timetable_view_flash", :text => ((@all_timetable_entries.present? and @mployee.present?) ? "" : (@all_timetable_entries.present? ? (@employee.present? ? "" : "<p class='flash-msg'>#{t('no_timetable_associated_employees_found')}</p>") : "<p class='flash-msg'>#{t('no_entries_found')}</p>" ))
        page.replace_html "teachers_list_view", :partial => "teacher_list"
        page.replace_html "teacher_timetable_view", :partial => "indepth_timetable/employee_timetable" if @employee.present?
        page.replace_html "teacher_timetable_view", :text => "" unless @employee.present?
      end
    end






  end

end