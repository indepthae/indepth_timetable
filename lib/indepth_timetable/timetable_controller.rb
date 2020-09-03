
module IndepthTimetable
  module IndepthTimetableController
    def self.included(base)
      base.instance_eval do

        alias_method_chain :update_timetable_view, :indepth

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




  end

end