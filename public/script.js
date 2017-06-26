$('.checkForPayment').submit(function(){
    $('.paymentButton')
    .prop('disabled', true)
    .text('Searching\u2026')
    .addClass('pleaseWait');
});
