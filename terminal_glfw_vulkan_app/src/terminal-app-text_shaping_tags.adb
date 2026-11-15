package body Terminal.App.Text_Shaping_Tags is
   package RM renames Terminal.App.Render_Model;

   function Direction_Tag
     (Direction : RM.Text_Run_Direction) return String
   is
   begin
      case Direction is
         when RM.Direction_Right_To_Left =>
            return "rtl";
         when RM.Direction_Left_To_Right =>
            return "ltr";
         when RM.Direction_Neutral =>
            return "ltr";
      end case;
   end Direction_Tag;

   function Script_Tag (Script : RM.Text_Run_Script) return String is
   begin
      case Script is
         when RM.Script_Latin =>
            return "latn";
         when RM.Script_Greek =>
            return "grek";
         when RM.Script_Cyrillic =>
            return "cyrl";
         when RM.Script_Glagolitic =>
            return "glag";
         when RM.Script_Coptic =>
            return "copt";
         when RM.Script_Gothic =>
            return "goth";
         when RM.Script_Old_Italic =>
            return "ital";
         when RM.Script_Old_Persian =>
            return "xpeo";
         when RM.Script_Ugaritic =>
            return "ugar";
         when RM.Script_Linear_B =>
            return "linb";
         when RM.Script_Cypriot =>
            return "cprt";
         when RM.Script_Egyptian_Hieroglyphs =>
            return "egyp";
         when RM.Script_Anatolian_Hieroglyphs =>
            return "hluw";
         when RM.Script_Old_Permic =>
            return "perm";
         when RM.Script_Elbasan =>
            return "elba";
         when RM.Script_Caucasian_Albanian =>
            return "aghb";
         when RM.Script_Mro =>
            return "mroo";
         when RM.Script_Bassa_Vah =>
            return "bass";
         when RM.Script_Pahawh_Hmong =>
            return "hmng";
         when RM.Script_Linear_A =>
            return "lina";
         when RM.Script_Phaistos_Disc =>
            return "disc";
         when RM.Script_Cuneiform =>
            return "xsux";
         when RM.Script_Lycian =>
            return "lyci";
         when RM.Script_Carian =>
            return "cari";
         when RM.Script_Old_Turkic =>
            return "orkh";
         when RM.Script_Medefaidrin =>
            return "medf";
         when RM.Script_Toto =>
            return "toto";
         when RM.Script_Wancho =>
            return "wcho";
         when RM.Script_Deseret =>
            return "dsrt";
         when RM.Script_Shavian =>
            return "shaw";
         when RM.Script_Osmanya =>
            return "osma";
         when RM.Script_Osage =>
            return "osge";
         when RM.Script_Bamum =>
            return "bamu";
         when RM.Script_Lisu =>
            return "lisu";
         when RM.Script_Miao =>
            return "plrd";
         when RM.Script_Nushu =>
            return "nshu";
         when RM.Script_Tangut =>
            return "tang";
         when RM.Script_Khitan_Small =>
            return "kits";
         when RM.Script_Armenian =>
            return "armn";
         when RM.Script_Georgian =>
            return "geor";
         when RM.Script_Ethiopic =>
            return "ethi";
         when RM.Script_Cherokee =>
            return "cher";
         when RM.Script_Canadian_Aboriginal =>
            return "cans";
         when RM.Script_Ogham =>
            return "ogam";
         when RM.Script_Runic =>
            return "runr";
         when RM.Script_Tifinagh =>
            return "tfng";
         when RM.Script_Vai =>
            return "vaii";
         when RM.Script_Hebrew =>
            return "hebr";
         when RM.Script_Arabic =>
            return "arab";
         when RM.Script_Syriac =>
            return "syrc";
         when RM.Script_Thaana =>
            return "thaa";
         when RM.Script_NKo =>
            return "nkoo";
         when RM.Script_Samaritan =>
            return "samr";
         when RM.Script_Mandaic =>
            return "mand";
         when RM.Script_Adlam =>
            return "adlm";
         when RM.Script_Hanifi_Rohingya =>
            return "rohg";
         when RM.Script_Imperial_Aramaic =>
            return "armi";
         when RM.Script_Palmyrene =>
            return "palm";
         when RM.Script_Nabataean =>
            return "nbat";
         when RM.Script_Hatran =>
            return "hatr";
         when RM.Script_Phoenician =>
            return "phnx";
         when RM.Script_Lydian =>
            return "lydi";
         when RM.Script_Avestan =>
            return "avst";
         when RM.Script_Inscriptional_Parthian =>
            return "prti";
         when RM.Script_Inscriptional_Pahlavi =>
            return "phli";
         when RM.Script_Psalter_Pahlavi =>
            return "phlp";
         when RM.Script_Old_South_Arabian =>
            return "sarb";
         when RM.Script_Old_North_Arabian =>
            return "narb";
         when RM.Script_Manichaean =>
            return "mani";
         when RM.Script_Tibetan =>
            return "tibt";
         when RM.Script_Devanagari =>
            return "deva";
         when RM.Script_Bengali =>
            return "beng";
         when RM.Script_Gurmukhi =>
            return "guru";
         when RM.Script_Gujarati =>
            return "gujr";
         when RM.Script_Oriya =>
            return "orya";
         when RM.Script_Tamil =>
            return "taml";
         when RM.Script_Telugu =>
            return "telu";
         when RM.Script_Kannada =>
            return "knda";
         when RM.Script_Malayalam =>
            return "mlym";
         when RM.Script_Sinhala =>
            return "sinh";
         when RM.Script_Brahmi =>
            return "brah";
         when RM.Script_Kaithi =>
            return "kthi";
         when RM.Script_Chakma =>
            return "cakm";
         when RM.Script_Mahajani =>
            return "mahj";
         when RM.Script_Sharada =>
            return "shrd";
         when RM.Script_Khojki =>
            return "khoj";
         when RM.Script_Khudawadi =>
            return "sind";
         when RM.Script_Grantha =>
            return "gran";
         when RM.Script_Newa =>
            return "newa";
         when RM.Script_Tirhuta =>
            return "tirh";
         when RM.Script_Siddham =>
            return "sidd";
         when RM.Script_Modi =>
            return "modi";
         when RM.Script_Takri =>
            return "takr";
         when RM.Script_Ahom =>
            return "ahom";
         when RM.Script_Dogra =>
            return "dogr";
         when RM.Script_Warang_Citi =>
            return "wara";
         when RM.Script_Dives_Akuru =>
            return "diak";
         when RM.Script_Nandinagari =>
            return "nand";
         when RM.Script_Zanabazar_Square =>
            return "zanb";
         when RM.Script_Soyombo =>
            return "soyo";
         when RM.Script_Thai =>
            return "thai";
         when RM.Script_Lao =>
            return "laoo";
         when RM.Script_Myanmar =>
            return "mymr";
         when RM.Script_Mongolian =>
            return "mong";
         when RM.Script_Limbu =>
            return "limb";
         when RM.Script_Tai_Le =>
            return "tale";
         when RM.Script_New_Tai_Lue =>
            return "talu";
         when RM.Script_Khmer =>
            return "khmr";
         when RM.Script_Balinese =>
            return "bali";
         when RM.Script_Sundanese =>
            return "sund";
         when RM.Script_Batak =>
            return "batk";
         when RM.Script_Lepcha =>
            return "lepc";
         when RM.Script_Ol_Chiki =>
            return "olck";
         when RM.Script_Syloti_Nagri =>
            return "sylo";
         when RM.Script_Phags_Pa =>
            return "phag";
         when RM.Script_Saurashtra =>
            return "saur";
         when RM.Script_Kayah_Li =>
            return "kali";
         when RM.Script_Rejang =>
            return "rjng";
         when RM.Script_Buginese =>
            return "bugi";
         when RM.Script_Tai_Tham =>
            return "lana";
         when RM.Script_Javanese =>
            return "java";
         when RM.Script_Cham =>
            return "cham";
         when RM.Script_Tai_Viet =>
            return "tavt";
         when RM.Script_Meetei_Mayek =>
            return "mtei";
         when RM.Script_Hiragana =>
            return "hira";
         when RM.Script_Katakana =>
            return "kana";
         when RM.Script_Bopomofo =>
            return "bopo";
         when RM.Script_Hangul =>
            return "hang";
         when RM.Script_Yi =>
            return "yiii";
         when RM.Script_Bhaiksuki =>
            return "bhks";
         when RM.Script_Braille =>
            return "brai";
         when RM.Script_Buhid =>
            return "buhd";
         when RM.Script_Chorasmian =>
            return "chrs";
         when RM.Script_Cypro_Minoan =>
            return "cpmn";
         when RM.Script_Duployan =>
            return "dupl";
         when RM.Script_Elymaic =>
            return "elym";
         when RM.Script_Gunjala_Gondi =>
            return "gong";
         when RM.Script_Hanunoo =>
            return "hano";
         when RM.Script_Kawi =>
            return "kawi";
         when RM.Script_Kharoshthi =>
            return "khar";
         when RM.Script_Makasar =>
            return "maka";
         when RM.Script_Marchen =>
            return "marc";
         when RM.Script_Masaram_Gondi =>
            return "gonm";
         when RM.Script_Mende_Kikakui =>
            return "mend";
         when RM.Script_Meroitic_Cursive =>
            return "merc";
         when RM.Script_Meroitic_Hieroglyphs =>
            return "mero";
         when RM.Script_Multani =>
            return "mult";
         when RM.Script_Nag_Mundari =>
            return "nagm";
         when RM.Script_Nyiakeng_Puachue_Hmong =>
            return "hmnp";
         when RM.Script_Old_Hungarian =>
            return "hung";
         when RM.Script_Old_Sogdian =>
            return "sogo";
         when RM.Script_Old_Uyghur =>
            return "ougr";
         when RM.Script_Pau_Cin_Hau =>
            return "pauc";
         when RM.Script_SignWriting =>
            return "sgnw";
         when RM.Script_Sogdian =>
            return "sogd";
         when RM.Script_Sora_Sompeng =>
            return "sora";
         when RM.Script_Tagalog =>
            return "tglg";
         when RM.Script_Tagbanwa =>
            return "tagb";
         when RM.Script_Tangsa =>
            return "tnsa";
         when RM.Script_Vithkuqi =>
            return "vith";
         when RM.Script_Yezidi =>
            return "yezi";
         when RM.Script_CJK =>
            return "hani";
         when RM.Script_Emoji =>
            return "zyyy";
         when RM.Script_Common | RM.Script_Unknown =>
            return "zyyy";
      end case;
   end Script_Tag;

   function Language_Tag return String is
   begin
      --  A script does not identify a language: Cyrillic may be Serbian,
      --  Russian, or another language, and Han may be Chinese or Japanese.
      --  Until run metadata carries an actual language, request HarfBuzz's
      --  language-neutral shaping behavior.
      return "und";
   end Language_Tag;

end Terminal.App.Text_Shaping_Tags;
