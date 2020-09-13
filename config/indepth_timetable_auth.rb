authorization do

  role :student do
    includes :special_timetable_view
  end

  role :parent do
    includes :special_timetable_view
  end

  role :employee do
    includes :special_timetable_view,
             :special_timetable_view_emp
    end

  role :admin do
    includes :special_timetable_view,
    :special_timetable_view_emp
  end

role :special_timetable_view do
  has_permission_on [:timetable], :to => [
                                          :special_sub_tt
  ]
  end
  role :special_timetable_view_emp do
    has_permission_on [:timetable], :to => [
        :special_sub_tt,
        :special_sub_tt_employee
    ]
end
end
