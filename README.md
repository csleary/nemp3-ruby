# NEMp3 - A Cryptocurrency Download Payment Portal #

NEMp3 is a Ruby/Sinatra web app that allows you to purchase music using the NEM cryptocurrency. A unique user ID hash is generated from a user email address, which is then included with a payment (as a NEM 'message'). NEMp3 searches for this ID on the blockchain, and if found, checks the amount paid, serving up a download button if the amount paid exceeds the minimum price set inside the app. Downloads are served via Amazon S3 buckets.

Please feel free to play with the testnet/dev version here: https://nemp3-testnet.herokuapp.com/

If you wish to use NEMp3 on your own site to sell your own music/downloads, please note the following:

- Change your payment address and price in the settings at the start of the app. I've set different addresses and nodes depending on the RACK_ENV, so you shouldn't need to automatically switch between mainnet/testnet addresses.
- Change the download link at the end (in the `/:download_link` route). If you're using Amazon S3, then just change the bucket and filenames as required (your AWS credentials will be used if they're available as environment variables), and if using a raw download URL, just replace the whole route with 'redirect URL' (replacing 'URL' with your actual link, e.g. `redirect https://domain/my-download.zip`). Please note, using raw unsigned urls isn't recommended, as the URLs can easily be shared.
- Other than the default AWS environment variables, NEMp3 uses a secret hash to salt email addresses. Please set this on your server using the 'NEMP3_SECRET' key, otherwise it'll be empty and so won't salt anything.

Should anything be amiss, please feel free to open an issue ticket and I'll look into it.

For more information on the NEM cryptocurrency, please visit https://www.nem.io/.

Thanks!

Chris
