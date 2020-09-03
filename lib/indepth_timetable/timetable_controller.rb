
module IndepthTimetable
  module IndepthTimetableController
    def self.included(base)
      base.instance_eval do

        alias_method_chain :update_timetable_view, :indepth
        alias_method_chain :timetable_pdf, :indepth
        alias_method_chain :update_student_tt, :indepth

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






  end

end