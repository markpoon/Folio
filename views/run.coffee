Lovely ["dom", "ajax", "sugar", "fx", "ui", "zoom", "glyph-icons", "hello-ie"], ($, ajax, fx, ui, zoom) ->  
  $("#browse").hide()
  togglebuttons = ->
    $("#browse").toggle()
    $("#more").toggle()
    @
    
  $("#more").onClick ->
    count = $(".entries")[0]._.childElementCount
    ajax.get "/folio",
      params: {"skip": count}
      success: (event)->
        ".entries".append(event.ajax.responseText)
        el = document.getElementById($(".entries")[0]._.children[count].id)
        el.scrollIntoView true
        @
        
  $("#search").remotize
    complete: ->
      togglebuttons()
      @
    success: (event)->
      ".entries".html(event.ajax.responseText)
      @
    failure: ->
      ".entries".html("No Examples Found")
      @
      
  $("#browse").onClick ->
    togglebuttons()
    ".entries".html("")
    $("#more").emit("click")
    @