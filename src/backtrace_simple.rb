  set_trace_func proc {|event, file, line, id, binding, klass, *nothing|
   print event,  ' ', file, ' ', line, ' ',klass, "\n"
  }
