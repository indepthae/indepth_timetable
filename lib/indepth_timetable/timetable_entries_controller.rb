
module IndepthTimetable
  module IndepthTimetableEntriesController
    def self.included(base)
      base.instance_eval do

        alias_method_chain :new, :indepth
        alias_method_chain :new_entry, :indepth
        alias_method_chain :update_employees, :indepth
        alias_method_chain :update_multiple_timetable_entries2, :indepth
        alias_method_chain :tt_entry_update2, :indepth
        alias_method_chain :delete_employee2, :indepth
      end
    end

    def new_with_indepth
      @tt=Timetable.find(params[:timetable_id], :include => {:time_table_class_timings => {:batch => [:course,:subjects, {:elective_groups => :subjects}]}})
      #    @batches=Batch.active.all(:select=>"DISTINCT `batches`.*,CONCAT(courses.code,'-',batches.name) as course_full_name",:joins=>[:time_table_class_timings],:conditions=>["time_table_class_timings.timetable_id=?  AND batches.start_date <= ? AND batches.end_date >= ?",@timetable.id,@timetable.end_date,@timetable.start_date])
      #    if params[:timetable_type].present? and params[:timetable_type]=="past"
      #      @timetable.dependency_delete(@timetable.start_date,@timetable.end_date,params[:timetable_type],@timetable.id)
      #      classroom_alloc_ids = ClassroomAllocation.find(:all, :conditions => {:allocation_type => "weekly"}).collect{|ca| ca.id}
      #      tte_ids = @timetable.timetable_entries.collect{|tte| tte.id}
      #      AllocatedClassroom.delete_all(["date IS NULL and classroom_allocation_id IN (?) and timetable_entry_id IN (?)",classroom_alloc_ids,tte_ids])
      #    end
      batches = @tt.time_table_class_timings.map {|x| x.batch if (x.batch.is_active and !x.batch.is_deleted and x.batch.start_date <= @tt.end_date and x.batch.end_date >= @tt.start_date)}.compact
      batches = batches.select {|x| (x.elective_groups.select{|y| !y.is_deleted and y.subjects.select{|z| !z.is_deleted }.present?}.present? or x.subjects.select{|y| (!y.is_deleted and !y.elective_group_id.present?)}.present?) }
      @courses = batches.map {|x| x.course}.uniq
      #    @courses = Course.active(:conditions => {}, :include => :batches)
      @timetable_batch_ids = batches.map(&:id) if batches.present?
      @is_batch_present = @timetable_batch_ids && @timetable_batch_ids.include?(params[:batch_id].try(:to_i))
      if @courses.present? && params[:batch_id].present? && @is_batch_present
        @batch = Batch.find(params[:batch_id],:include => [:employees,{:course => :batches},:subjects, {:elective_groups => :subjects } ])
        @course = @batch.course
        @batches = batches.select{|x| x.course_id == @course.id }
        tte_from_batch_and_tt(@tt.id)
      else
        flash.now[:notice] = t('batch_not_associated_with_timetable') unless @is_batch_present
        flash.now[:notice] = t('no_batches_in_this_timetable') unless @courses.present?
      end
      render 'indepth_timetable_entries/new'
    end

    def new_entry_with_indepth
      puts "inside  new entry with indepth"
      @online = {}
      @timetable=Timetable.find(params[:timetable_id])
      if params[:batch_id] == ""
        render :update do |page|
          page.replace_html "render_area", :text => ""
        end
        return
      end
      @batch = Batch.find(params[:batch_id],:include => [:employees,:subjects, {:elective_groups => :subjects } ])
      tte_from_batch_and_tt(@timetable.id)

      render :update do |page|
        page.replace_html "inner-tab-menu", :partial => "inner_tab_link"
        page.replace_html "tutor_list", :partial => "tutor_list"
        page.replace_html "render_area", :partial => "indepth_table_entries/new_entry"
      end
    end

    def update_employees_with_indepth

      #    @weekday = ["#{t('sun')}", "#{t('mon')}", "#{t('tue')}", "#{t('wed')}", "#{t('thu')}", "#{t('fri')}", "#{t('sat')}"]
      if params[:subject_id] == ""
        render :text => ""
        return
      end
      ele_gp_id=Subject.find_all_by_id(params[:subject_id]).collect(&:elective_group_id).compact
      if ele_gp_id.empty?
        @employees_subject = EmployeesSubject.find_all_by_subject_id(params[:subject_id])
      else
        @employees_subject = EmployeesSubject.find_all_by_subject_id(Subject.find_all_by_elective_group_id(ele_gp_id).collect(&:id))
      end
      render :partial=>"indepth_timetable_entries/employee_list"
    end

    def delete_employee2_with_indepth
      @errors = {"messages" => []}
      tte=TimetableEntry.find(params[:id])
      batch=tte.batch_id
      #    @timetable = TimetableEntry.find_all_by_batch_id(tte.batch_id)
      @batch=Batch.find batch
      @timetable=Timetable.find(tte.timetable_id)
      unless  tte.destroy
        flash[:warn_notice]=tte.errors.full_messages.first
      end
      tte_from_batch_and_tt(@timetable.id)
      render :update do |page|
        page.replace 'tt_over',:partial=>'indepth_timetable_entries/new_entry', :batch_id=>batch
      end
    end

    def update_multiple_timetable_entries2_with_indepth
      @is_online = params[:is_online]
      @meeting_link = params[:meeting_link]
      @meeting_link.present? ? @meeting_link.sub!('@@','?') : ''
      @meeting_id = params[:meeting_id]
      @meeting_passcode = params[:meeting_passcode]
      @timetable=Timetable.find(params[:timetable_id])
      @gclass_code = params[:gclass_code]

      employees_subjects = EmployeesSubject.find_all_by_id(params[:emp_sub_id].split(',').sort, :include => :subject)
      employees_subject = employees_subjects.first
      elective_ids = employees_subjects.collect { |es| es.subject.elective_group_id }.reject { |eg| !eg.present? }.uniq
      sub_ids=params[:emp_sub_id].split(",")
      emp_ids=EmployeesSubject.find_all_by_id(sub_ids).collect(&:employee_id)
      tte_ids = params[:tte_ids].split(",").each {|x| x}
      @batch = employees_subject.subject.batch
      timetable_class_timings=[]
      time_table_class_timing_sets = TimeTableClassTiming.find_by_batch_id_and_timetable_id(@batch.id,@timetable.id).try(:time_table_class_timing_sets)
      time_table_class_timing_sets && time_table_class_timing_sets.each do |ttcts|
        timetable_class_timings += ttcts.class_timing_set.class_timings.timetable_timings.map(&:id)
      end
      timetable_class_timings.uniq!
      subject = employees_subject.subject
      employee = employees_subject.employee
      emp_s=employee.subjects.collect(&:elective_group_id).compact
      @validation_problems = {}
      # validate class timings
      class_timing_set_not_found = []
      tte_ids.map {|x| coordinates  = x.split("_"); ct_id = coordinates.last.to_i; ct = ClassTiming.find(ct_id); class_timing_set_not_found << coordinates.last unless BatchClassTimingSet.find_by_batch_id_and_class_timing_set_id_and_weekday_id(@batch.id,ct.class_timing_set_id,coordinates.first.to_i).present? }
      if !time_table_class_timing_sets || class_timing_set_not_found.compact.present?
        flash_notice = t('batch_class_timing_sets_modified') #if class_timing_set_not_found.compact.present?
        render :update do |page|
          page << "build_page_refresh(#{@timetable.id},#{@batch.id},'#{flash_notice}')"
        end
        #      render :controller => :user, :action => :dashboard
      else
        tte_ids.each do |tte_id|
          co_ordinate=tte_id.split("_")
          weekday=co_ordinate[0].to_i
          class_timing=co_ordinate[1].to_i
          classtiming = ClassTiming.find(class_timing)
          employees = Employee.find(emp_ids)
          ttes = employees.map {|emp| emp.timetable_entries.all(:joins => "LEFT OUTER JOIN batches b on b.id=timetable_entries.batch_id LEFT OUTER JOIN class_timings ct on timetable_entries.class_timing_id = ct.id", :conditions => ["b.is_active = ? and timetable_entries.timetable_id = ? and timetable_entries.weekday_id = ? and timetable_entries.batch_id <> ? and ((ct.start_time BETWEEN ? and ?) or (ct.end_time BETWEEN ? and ?) or (? BETWEEN ct.start_time and ct.end_time) or (? BETWEEN ct.start_time and ct.end_time))", true,@timetable.id, weekday,@batch.id, (classtiming.start_time).strftime("%H:%M:%S"), (classtiming.end_time-1).strftime("%H:%M:%S"), (classtiming.start_time+1).strftime("%H:%M:%S"), (classtiming.end_time).strftime("%H:%M:%S"),(classtiming.start_time+1).strftime("%H:%M:%S"),(classtiming.end_time-1).strftime("%H:%M:%S")]) }.flatten.uniq
          overlap = ttes.map {|tte| {tte => (tte.employee_ids & emp_ids)}}.reject{ |x| !x.values.flatten.present? or !(x.values.flatten & emp_ids).present? }
          tte = TimetableEntry.find_by_weekday_id_and_class_timing_id_and_batch_id_and_timetable_id(weekday,class_timing,@batch.id,@timetable.id)
          unless overlap.empty?
            errors = { "info" => {"sub_id" => employees_subject.subject_id, "emp_id"=> emp_ids.join(','),"tte_id" => tte_id},
                       "messages" => [], "batches" => [] }
            overlap.uniq!
            @overlap = overlap.uniq
            overlap.each do |olap|
              unless errors['batches'].include? olap.keys[0].batch.id
                errors['batches'] << olap.keys[0].batch.id
                overlap_employees = Employee.find(olap.values).map(&:first_name)
                errors["messages"] << "#{t('class_overlap',:employee_names => overlap_employees.join(', '))} #{olap.keys[0].batch.full_name} #{t('for_text')} #{olap.keys[0].assigned_name}"
              end
            end
          else
            errors = { "info" => {"sub_id" => employees_subject.subject_id, "emp_id"=> emp_ids.join(','),"tte_id" => tte_id},
                       "messages" => [] }
          end
          if errors.empty?
            unless emp_s.empty?
              emp_subs=Subject.find_all_by_elective_group_id(emp_s).collect(&:id)
              overlap_elective=TimetableEntry.find(:all,:conditions=>{:subject_id=>emp_subs,:timetable_id=>@timetable.id,
                                                                      :class_timing_id=>class_timing,:weekday_id=>weekday},
                                                   :joins=>"INNER JOIN subjects ON timetable_entries.subject_id = subjects.id
                         INNER JOIN batches ON subjects.batch_id = batches.id AND batches.is_active = 1 AND batches.is_deleted = 0").uniq
              unless overlap_elective.empty?
                overlap_elective.each do |overlap|
                  unless errors['batches'].include? overlap_elective.keys[0].batch.id
                    errors["messages"] << "#{t('class_overlap')} #{overlap_elective.keys[0].batch.full_name}  #{t('for_text')} #{overlap_elective.keys[0].assigned_name}"
                  end
                end
              end
            end
          end

          search_id = subject.elective_group_id.nil?? subject.id : subject.elective_group_id
          subject_type = subject.elective_group_id.nil?? 'Subject':'ElectiveGroup'
          current_tte_ids = TimetableEntry.find(:all,:conditions => {:batch_id => @batch.id, :class_timing_id => class_timing, :timetable_id => @timetable.id, :weekday_id => weekday}).map(&:id)
          tte_subject_count = (current_tte_ids.present? ? TimetableEntry.find(:all,:conditions =>["entry_id = ? and entry_type = ? and timetable_id = ? and id not in (?)",search_id,subject_type,@timetable.id,current_tte_ids]) : TimetableEntry.find(:all,:conditions =>{:entry_id=>search_id,:entry_type=>subject_type,:timetable_id=>@timetable.id, :class_timing_id => timetable_class_timings})).count
          if subject_type == 'ElectiveGroup'
            hour_limit_exceeding_subjects = subject.elective_group.hour_count_check(tte_subject_count)
            errors["messages"] << "#{t('weekly_limit_reached', :subject_names => hour_limit_exceeding_subjects.join(', '))}" if hour_limit_exceeding_subjects.present?
          else
            errors["messages"] << "#{t('weekly_limit_reached', :subject_names => subject.name)}" if subject.max_weekly_classes <= tte_subject_count
          end

          # check for max hours per week & per day
          weekly_hour_exceeding_employees = []
          daily_hour_exceeding_employees = []
          employees.each do |emp|
            daily_hour_exceeding_employees << emp.first_name if (emp.max_hours_per_day <= TimetableEntry.find(:all,
                                                                                                              :conditions => "b.is_active = true and timetable_entries.timetable_id=#{@timetable.id} AND ttte.employee_id = #{emp.id} AND weekday_id = #{weekday}",
                                                                                                              :joins=>"LEFT OUTER JOIN batches b on b.id=timetable_entries.batch_id INNER JOIN teacher_timetable_entries ttte ON ttte.timetable_entry_id = timetable_entries.id").
                count unless emp.max_hours_per_day.nil? )
            #            select{|tt| timetable_class_timings.include? tt.class_timing_id}.count unless emp.max_hours_per_day.nil? )
            weekly_hour_exceeding_employees << emp.first_name if (emp.max_hours_per_week <= TimetableEntry.find(:all,
                                                                                                                :conditions => "b.is_active = true and timetable_entries.timetable_id=#{@timetable.id} AND ttte.employee_id = #{emp.id}",
                                                                                                                :joins=>"LEFT OUTER JOIN batches b on b.id=timetable_entries.batch_id INNER JOIN teacher_timetable_entries ttte ON ttte.timetable_entry_id = timetable_entries.id").
                count unless emp.max_hours_per_week.nil?)
            #            select{|tt| timetable_class_timings.include? tt.class_timing_id}.count unless emp.max_hours_per_week.nil?)
            #                     INNER JOIN subjects ON timetable_entries.subject_id = subjects.id
            #                     INNER JOIN batches ON subjects.batch_id = batches.id AND batches.is_active = 1 AND batches.is_deleted = 0").
          end
          errors["messages"] << "#{t('max_hour_exceeded_day',:employee_names => daily_hour_exceeding_employees.join(', '))}" if daily_hour_exceeding_employees.present?
          errors["messages"] << "#{t('max_hour_exceeded_week',:employee_names => weekly_hour_exceeding_employees.join(', '))}" if weekly_hour_exceeding_employees.present?

          if errors["messages"].empty?
            entry_id = elective_ids.present? ? elective_ids.first : subject.id
            entry_type = elective_ids.present? ? 'ElectiveGroup' : 'Subject'
            unless tte.nil?
              tte.employee_ids = emp_ids.present? ? (tte.entry_id == entry_id ? (tte.employee_ids + emp_ids).uniq : emp_ids.uniq ) : []
              tte = TimetableEntry.update(tte.id, :entry_id => entry_id, :entry_type => entry_type, :timetable_id=>@timetable.id,
                                          :is_online => @is_online ,
                                          :meeting_link => @meeting_link,
                                          :meeting_id => @meeting_id,
                                          :meeting_passcode => @meeting_passcode,
                                          :gclass_code => @gclass_code
              )
              tte.touch
              AllocatedClassroom.destroy_all("timetable_entry_id = #{tte.id}")
            else
              tte = @timetable.timetable_entries.build(
                  :weekday_id=>weekday,
                  :class_timing_id=>class_timing,
                  :batch_id=>@batch.id,
                  :timetable_id=>@timetable.id,
                  :is_online => @is_online,
                  :meeting_link => @meeting_link,
                  :meeting_id => @meeting_id,
                  :meeting_passcode => @meeting_passcode,
                  :gclass_code => @gclass_code
              )
              tte.entry_type = entry_type
              tte.entry_id = entry_id
              tte.employee_ids = emp_ids.uniq if emp_ids.present?
              tte.save
            end
          else
            errors["batches"] = nil
            @validation_problems[tte_id] = errors
          end
        end

        tte_from_batch_and_tt(@timetable.id)
        render :update do |page|
          page.replace 'tt_over',:partial=>'indepth_timetable_entries/new_entry'
        end
      end
    end

    def tt_entry_update2_with_indepth
      @is_online = params[:is_online]
      @meeting_link = params[:meeting_link]
      @meeting_link.present? ? @meeting_link.sub!('@@','?') : ''
      @meeting_id = params[:meeting_id]
      @meeting_passcode = params[:meeting_passcode]
      @gclass_code = params[:gclass_code]

      @errors = {"messages" => []}
      @timetable=Timetable.find(params[:timetable_id])
      @batch=Batch.find(params[:batch_id])
      subject = Subject.find(params[:sub_id])

      entry_type = subject.elective_group_id.present? ? 'ElectiveGroup' : 'Subject'
      co_ordinate=params[:tte_id].split("_")
      weekday=co_ordinate[0].to_i
      class_timing=co_ordinate[1].to_i
      emp_ids = params[:emp_id].present? ? params[:emp_id].split(',').collect { |x| x.to_i}.flatten.uniq : []
      employees = Employee.find(emp_ids,:include => :timetable_entries)
      classtiming = ClassTiming.find(class_timing)
      overlapped_tte = []
      overlapped_tte = employees.map {|emp| emp.timetable_entries.all(:joins => "LEFT OUTER JOIN class_timings ct on timetable_entries.class_timing_id = ct.id", :conditions => ["timetable_entries.timetable_id = ? and timetable_entries.weekday_id = ? and timetable_entries.batch_id <> ? and ((ct.start_time BETWEEN ? and ?) or (ct.end_time BETWEEN ? and ?) or (? BETWEEN ct.start_time and ct.end_time) or (? BETWEEN ct.start_time and ct.end_time))",@timetable.id, weekday, @batch.id, (classtiming.start_time).strftime("%H:%M:%S"), (classtiming.end_time-1).strftime("%H:%M:%S"), (classtiming.start_time+1).strftime("%H:%M:%S"), (classtiming.end_time).strftime("%H:%M:%S"),(classtiming.start_time+1).strftime("%H:%M:%S"),(classtiming.end_time-1).strftime("%H:%M:%S")]) }.flatten.uniq
      if params[:overwrite].present?
        overlapped_tte.each do |o_tte|
          if subject.id == o_tte.entry_id and o_tte.entry_type == entry_type
            o_tte.destroy unless (o_tte.employee_ids - emp_ids).present?
            o_tte.employee_ids = (o_tte.employee_ids - emp_ids) if (o_tte.employee_ids - emp_ids).present?
          else
            o_tte.destroy
          end
        end
      end

      entry_id = subject.elective_group_id.present? ? subject.elective_group_id : subject.id
      tte = TimetableEntry.find_by_weekday_id_and_class_timing_id_and_batch_id_and_timetable_id(
          weekday,class_timing,@batch.id,@timetable.id)
      unless tte.nil?
        previous_subject = tte.entry if tte.present?
        tte = TimetableEntry.update(tte.id, :entry_id => entry_id,
                                    :entry_type => entry_type,
                                    :is_online => @is_online,
                                    :meeting_link => @meeting_link,
                                    :meeting_id => @meeting_id,
                                    :meeting_passcode => @meeting_passcode,
                                    :gclass_code => @gclass_code
        )
      else
        tte = TimetableEntry.create(:weekday_id=>weekday,:class_timing_id=>class_timing,
                                    :entry_id => entry_id,
                                    :entry_type => entry_type,
                                    :batch_id=>@batch.id,
                                    :timetable_id=>@timetable.id,
                                    :is_online => @is_online,
                                    :meeting_link => @meeting_link,
                                    :meeting_id => @meeting_id,
                                    :meeting_passcode => @meeting_passcode,
                                    :gclass_code => @gclass_code
        )
      end
      if previous_subject.present? and previous_subject.id == entry_id and previous_subject.class.name == entry_type
        tte.employee_ids = (tte.employee_ids << emp_ids).flatten.uniq.compact
      else
        tte.employee_ids = emp_ids
      end

      tte_from_batch_and_tt(@timetable.id)
      render :update do |page|
        page.replace_html 'tt_over',:partial=>'indepth_timetable_entries/new_entry'
        #      page.replace_html "box", :partial=> "timetable_box"
        #      page.replace_html "subjects-select", :partial=> "employee_select"
        page.replace_html "error_div_#{params[:tte_id]}", :text => "<div class='allotted'></div><div class='msg_text'>#{t('allocated')}</div><div id='problem_ct1'>#{WeekdaySet.default_weekdays[params[:week_day].to_s].capitalize}, #{format_date(ClassTiming.find(params[:class_timing]).start_time,:format=>:time)}-#{format_date(ClassTiming.find(params[:class_timing]).end_time,:format=>:time)}</div>#{params[:overwrite].present? ? "<div id='descr_msg'>" + t('removed') + ' ' + @batch.name + ' ' + t('for_text') + ' ' + subject.name + "</div>" : ''}"
      end
    end





  end

end