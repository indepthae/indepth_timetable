namespace :indepth_timetable do
  desc "Install InDepth Timetable"
  task :install do
    system "rsync --exclude=.svn -ruv vendor/plugins/indepth_timetable/public ."
  end

  #  desc "Migrate all migrations ="
  task :migrate => :environment do
    ActiveRecord::Migrator.migrate("vendor/plugins/indepth_timetable/db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end
end