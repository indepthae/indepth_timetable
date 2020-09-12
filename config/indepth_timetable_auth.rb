authorization do

  role :student do
    includes :special_timetable_view
  end

  role :employee do
    includes :special_timetable_view
    end

  role :admin do
    includes :special_timetable_view
  end

role :special_timetable_view do
  has_permission_on [:timetable], :to => [
                                          :special_sub_tt
  ]
end
end
