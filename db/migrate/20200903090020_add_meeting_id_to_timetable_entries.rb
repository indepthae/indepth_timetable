class AddMeetingIdToTimetableEntries < ActiveRecord::Migration
  def self.up
    add_column :timetable_entries, :meeting_id, :string
  end

  def self.down
    remove_column :timetable_entries, :meeting_id
  end
end
