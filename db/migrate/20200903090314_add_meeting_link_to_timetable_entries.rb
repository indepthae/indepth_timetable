class AddMeetingLinkToTimetableEntries < ActiveRecord::Migration
  def self.up
    add_column :timetable_entries, :meeting_link, :string
  end

  def self.down
    remove_column :timetable_entries, :meeting_link
  end
end
