$(document).on 'page:change', ->
  $(".company-carousel").owlCarousel
    items:4
    loop:true
    margin:10
    autoplay:true

  $(".testimonial-carousel").owlCarousel
    items:1
    loop:true
