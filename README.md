# NEMp3 - A Cryptocurrency Download Payment Portal #

NEMp3 is a Ruby/Sinatra web app that allows you to purchase music using the NEM cryptocurrency. A unique user ID hash is generated from a user email address, which is then included with a payment (as a NEM 'message'). NEMp3 searches for this ID on the blockchain, and if found, checks the amount paid, serving up a download button if the amount paid exceeds the minimum set inside the app. Downloads are served via Amazon S3 buckets.

If you wish to use NEMp3 on your own site to sell your own music/downloads, please note the following:

- Change your payment address and price in the settings at the start of the app.
- Change the download link at the end (in the '/:download_link' route). If you're using Amazon S3, then just change the bucket and filenames as required (your AWS credentials will be used if they're available as environment variables), and if using a raw download URL, just replace the whole route with 'redirect url' (replacing 'url' with your actual link, e.g. 'redirect https://my.download.zip').
- Other than the default Amazon environment variables, NEMp3 uses a secret hash to salt email addresses. Please set this on your server under the 'NEMP3_SECRET' key.

For more information on the NEM cryptocurrency, please visit https://www.nem.io/.
