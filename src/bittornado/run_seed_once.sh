rm -rf ~/.BitTornado/
python ./btdownloadheadless.seed.py --saveas ./30000K.file ./torrent.30000K.file.torrent --max_upload_rate 256 --spew 4
rm -rf ~/.BitTornado/

