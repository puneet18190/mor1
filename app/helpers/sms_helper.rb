module SmsHelper
	def sms_prov_encodings
		[ %w[SMSC\ Default\ Alphabet smsc_default],
		  %w[IA5\ (CCITT\ T.50)/ASCII\ (ANSI\ X3.4) ia5],
	      %w[Latin\ 1\ (ISO-8859-1) latin1],
		  %w[JIS\ (X\ 0208-1990) jis],
		  %w[Cyrillic\ (ISO-8859-5) cyrllic],
		  %w[Latin/Hebrew\ (ISO-8859-8) latin_hebrew],
		  %w[UCS2\ (ISO/IEC-10646) ucs2],
		  %w[Pictogram\ Encoding pictogram],
		  %w[ISO-2022-JP\ (Music\ Codes) music_codes],
		  %w[Extended\ Kanji\ JIS\ (X\ 0212-1990) extended_kanjiJis],
		  %w[KS\ C\ 5601 ksc5601],
		  %w[GSM\ MWI\ control\ -\ see\ GSM\ 03.38 gsm_mwi],
		  %w[GSM\ message\ class\ control\ -\ see\ GSM\ 03.38 gsm_ctl]
		]
	end
end