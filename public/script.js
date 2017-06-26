$('.checkForPayment').submit(function(){
    $('.paymentButton')
    .prop('disabled', true)
    .text('Searching...')
    .addClass('pleaseWait');
});
