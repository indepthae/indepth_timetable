# IndepthReportCard
require 'dispatcher'
require 'indepth_timetable/timetable_controller'
require 'indepth_timetable/timetable_entries_controller'
module IndepthTimetable
  def self.attach_overrides
    Dispatcher.to_prepare  do
      ::TimetableEntriesController.instance_eval {include IndepthTimetable::IndepthTimetableEntriesController}
      ::TimetableController.instance_eval {include IndepthTimetable::IndepthTimetableController}
    end
  end

end