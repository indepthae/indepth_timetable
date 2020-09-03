class AddIsOnlineToTimetableEntries < ActiveRecord::Migration
  def self.up
    add_column :timetable_entries, :is_online, :boolean
  end

  def self.down
    remove_column :timetable_entries, :is_online
  end
end
