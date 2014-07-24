<?php
  define('ABSPATH', dirname(__FILE__) . '/'); 
  $before = get_defined_constants();
  include $argv[1];
  $after = get_defined_constants();
  foreach ($before as $k => $v) {
    unset($after[$k]);
  }
  print json_encode($after);
?>
