with Ada.Directories;

with AUnit.Assertions;

with Terminal.App.Fonts;

procedure Font_Discovery_Smoke is
   use AUnit.Assertions;

   package Fonts renames Terminal.App.Fonts;

   Noto_Devanagari : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf";
   Noto_Brahmi : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansBrahmi-Regular.ttf";
   Noto_Sharada : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansSharada-Regular.ttf";
   Noto_Newa : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansNewa-Regular.ttf";
   Noto_Tirhuta : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansTirhuta-Regular.ttf";
   Noto_Siddham : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansSiddham-Regular.ttf";
   Noto_Modi : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansModi-Regular.ttf";
   Noto_Dogra : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansDogra-Regular.ttf";
   Noto_Soyombo : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansSoyombo-Regular.ttf";
   Noto_Khmer : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansKhmer-Regular.ttf";
   Noto_Tai_Viet : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansTaiViet-Regular.ttf";
   Noto_Meetei : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansMeeteiMayek-Regular.ttf";
   Noto_Samaritan : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansSamaritan-Regular.ttf";
   Noto_Mandaic : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansMandaic-Regular.ttf";
   Noto_Adlam : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansAdlam-Regular.ttf";
   Noto_Rohingya : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansHanifiRohingya-Regular.ttf";
   Noto_Aramaic : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansImperialAramaic-Regular.ttf";
   Noto_Palmyrene : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansPalmyrene-Regular.ttf";
   Noto_Nabataean : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansNabataean-Regular.ttf";
   Noto_Hatran : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansHatran-Regular.ttf";
   Noto_Phoenician : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansPhoenician-Regular.ttf";
   Noto_Lydian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansLydian-Regular.ttf";
   Noto_Avestan : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansAvestan-Regular.ttf";
   Noto_Parthian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansInscriptionalParthian-Regular.ttf";
   Noto_Pahlavi : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansInscriptionalPahlavi-Regular.ttf";
   Noto_Psalter : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansPsalterPahlavi-Regular.ttf";
   Noto_Old_South_Arabian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansOldSouthArabian-Regular.ttf";
   Noto_Old_North_Arabian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansOldNorthArabian-Regular.ttf";
   Noto_Manichaean : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansManichaean-Regular.ttf";
   Noto_Linear_A : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansLinearA-Regular.ttf";
   Noto_Linear_B : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansLinearB-Regular.ttf";
   Noto_Cuneiform : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansCuneiform-Regular.ttf";
   Noto_Lycian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansLycian-Regular.ttf";
   Noto_Carian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansCarian-Regular.ttf";
   Noto_Old_Turkic : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansOldTurkic-Regular.ttf";
   Noto_Medefaidrin : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansMedefaidrin-Regular.ttf";
   Noto_Wancho : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansWancho-Regular.ttf";
   Noto_Deseret : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansDeseret-Regular.ttf";
   Noto_Shavian : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansShavian-Regular.ttf";
   Noto_Osmanya : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansOsmanya-Regular.ttf";
   Noto_Osage : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansOsage-Regular.ttf";
   Noto_Bamum : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansBamum-Regular.ttf";
   Noto_Lisu : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansLisu-Regular.ttf";
   Noto_Miao : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansMiao-Regular.ttf";
   Noto_Nushu : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansNushu-Regular.ttf";
   Noto_Tangut : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSerifTangut-Regular.ttf";

   Default_Path : constant String := Fonts.Default_Font_Path;
   Fallbacks    : constant Fonts.Font_Path_Array := Fonts.Fallback_Font_Paths;

   function Contains (Path : String) return Boolean is
   begin
      for Fallback of Fallbacks loop
         if Fonts.To_String (Fallback) = Path then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   procedure Assert_Contains_If_Installed (Path : String; Label : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Assert
           (Contains (Path),
            "installed " & Label & " fallback should be discovered");
      end if;
   end Assert_Contains_If_Installed;
begin
   Assert (Default_Path /= "", "default font path should resolve");
   Assert
     (Fallbacks'Length <= Fonts.Max_Fallback_Fonts,
      "fallback list should fit configured bound");

   for I in Fallbacks'Range loop
      declare
         Path : constant String := Fonts.To_String (Fallbacks (I));
      begin
         Assert (Path /= "", "fallback path should not be empty");
         Assert (Path /= Default_Path, "fallback should not duplicate primary");

         for J in Fallbacks'First .. I - 1 loop
            Assert
              (Fonts.To_String (Fallbacks (J)) /= Path,
               "fallback paths should be unique");
         end loop;
      end;
   end loop;

   Assert_Contains_If_Installed (Noto_Devanagari, "Devanagari");
   Assert_Contains_If_Installed (Noto_Brahmi, "Brahmi");
   Assert_Contains_If_Installed (Noto_Sharada, "Sharada");
   Assert_Contains_If_Installed (Noto_Newa, "Newa");
   Assert_Contains_If_Installed (Noto_Tirhuta, "Tirhuta");
   Assert_Contains_If_Installed (Noto_Siddham, "Siddham");
   Assert_Contains_If_Installed (Noto_Modi, "Modi");
   Assert_Contains_If_Installed (Noto_Dogra, "Dogra");
   Assert_Contains_If_Installed (Noto_Soyombo, "Soyombo");
   Assert_Contains_If_Installed (Noto_Khmer, "Khmer");
   Assert_Contains_If_Installed (Noto_Tai_Viet, "Tai Viet");
   Assert_Contains_If_Installed (Noto_Meetei, "Meetei Mayek");
   Assert_Contains_If_Installed (Noto_Samaritan, "Samaritan");
   Assert_Contains_If_Installed (Noto_Mandaic, "Mandaic");
   Assert_Contains_If_Installed (Noto_Adlam, "Adlam");
   Assert_Contains_If_Installed (Noto_Rohingya, "Hanifi Rohingya");
   Assert_Contains_If_Installed (Noto_Aramaic, "Imperial Aramaic");
   Assert_Contains_If_Installed (Noto_Palmyrene, "Palmyrene");
   Assert_Contains_If_Installed (Noto_Nabataean, "Nabataean");
   Assert_Contains_If_Installed (Noto_Hatran, "Hatran");
   Assert_Contains_If_Installed (Noto_Phoenician, "Phoenician");
   Assert_Contains_If_Installed (Noto_Lydian, "Lydian");
   Assert_Contains_If_Installed (Noto_Avestan, "Avestan");
   Assert_Contains_If_Installed
     (Noto_Parthian, "Inscriptional Parthian");
   Assert_Contains_If_Installed (Noto_Pahlavi, "Inscriptional Pahlavi");
   Assert_Contains_If_Installed (Noto_Psalter, "Psalter Pahlavi");
   Assert_Contains_If_Installed
     (Noto_Old_South_Arabian, "Old South Arabian");
   Assert_Contains_If_Installed
     (Noto_Old_North_Arabian, "Old North Arabian");
   Assert_Contains_If_Installed (Noto_Manichaean, "Manichaean");
   Assert_Contains_If_Installed (Noto_Linear_A, "Linear A");
   Assert_Contains_If_Installed (Noto_Linear_B, "Linear B");
   Assert_Contains_If_Installed (Noto_Cuneiform, "Cuneiform");
   Assert_Contains_If_Installed (Noto_Lycian, "Lycian");
   Assert_Contains_If_Installed (Noto_Carian, "Carian");
   Assert_Contains_If_Installed (Noto_Old_Turkic, "Old Turkic");
   Assert_Contains_If_Installed (Noto_Medefaidrin, "Medefaidrin");
   Assert_Contains_If_Installed (Noto_Wancho, "Wancho");
   Assert_Contains_If_Installed (Noto_Deseret, "Deseret");
   Assert_Contains_If_Installed (Noto_Shavian, "Shavian");
   Assert_Contains_If_Installed (Noto_Osmanya, "Osmanya");
   Assert_Contains_If_Installed (Noto_Osage, "Osage");
   Assert_Contains_If_Installed (Noto_Bamum, "Bamum");
   Assert_Contains_If_Installed (Noto_Lisu, "Lisu");
   Assert_Contains_If_Installed (Noto_Miao, "Miao");
   Assert_Contains_If_Installed (Noto_Nushu, "Nushu");
   Assert_Contains_If_Installed (Noto_Tangut, "Tangut");
end Font_Discovery_Smoke;
