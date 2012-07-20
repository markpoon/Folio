Lovely ["dom-1.2.0", "sugar-1.0.3", "fx-1.0.3", "ui-2.0.1", "zoom-1.1.0", "killie-1.0.0"], ($, fx, ui, zoom) ->  
  $(document).on "ready", ->
    "footer".hide()
    "#loginimage".onClick ->
      "footer".toggle "fade"