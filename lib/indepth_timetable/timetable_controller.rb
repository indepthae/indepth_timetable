
module IndepthTimetable
  module IndepthTimetableController
    def self.included(base)
      base.instance_eval do

        alias_method_chain :update_timetable_view, :indepth
        alias_method_chain :timetable_pdf, :indepth

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




  end

end