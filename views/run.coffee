$(document).onReady ->
  "footer".hide "fade"
  "#loginimage".onClick ->
    "footer".toggle "fade"