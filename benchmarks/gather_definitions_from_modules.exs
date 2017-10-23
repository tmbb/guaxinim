Benchee.run(%{
  "sequential"   => fn -> Guaxinim.BeamInspector.gather_data_from_modules__sequential() end,
  "async stream" => fn -> Guaxinim.BeamInspector.gather_data_from_modules__async_stream() end,
  "task async" => fn -> Guaxinim.BeamInspector.gather_data_from_modules__task_async() end
})