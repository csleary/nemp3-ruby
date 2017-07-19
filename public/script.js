$('.please-wait-form').submit(function() {
  $('.please-wait-button')
  .prop('disabled', true)
  .text('Searching\u2026')
  .addClass('please-wait');
});
