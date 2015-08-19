$(document).ready ->
  $("#projects").justifiedGallery(
    lastrow: 'justify',
    margins: 0,
    rowHeight: 300 ).on 'jg.complete', ->
      $('#projects a').swipebox()
  $('.carousel').carousel()
  null
