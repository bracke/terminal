with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;

with Textrender.Fonts;

package body Terminal.App.Fonts is
   use type Ada.Directories.File_Kind;
   use type Textrender.Fonts.Load_Result;

   type Candidate_Array is array (Positive range <>) of access constant String;

   Noto_Mono     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf";
   DejaVu_Mono   : aliased constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
   Liberation2   : aliased constant String := "/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf";
   Liberation    : aliased constant String := "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf";
   Noto_Old_Mono : aliased constant String := "/usr/share/fonts/truetype/noto/NotoMono-Regular.ttf";
   DejaVu_Sans   : aliased constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";
   Noto_Sans     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf";
   Noto_Symbols  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSymbols-Regular.ttf";
   Noto_Symbols2 : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf";
   Noto_Arabic   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf";
   Noto_Hebrew   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansHebrew-Regular.ttf";
   Noto_Samaritan : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSamaritan-Regular.ttf";
   Noto_Mandaic  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMandaic-Regular.ttf";
   Noto_Adlam    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansAdlam-Regular.ttf";
   Noto_Rohingya : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansHanifiRohingya-Regular.ttf";
   Noto_Aramaic  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansImperialAramaic-Regular.ttf";
   Noto_Palmyrene : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansPalmyrene-Regular.ttf";
   Noto_Nabataean : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansNabataean-Regular.ttf";
   Noto_Hatran   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansHatran-Regular.ttf";
   Noto_Phoenician : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansPhoenician-Regular.ttf";
   Noto_Lydian   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLydian-Regular.ttf";
   Noto_Avestan  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansAvestan-Regular.ttf";
   Noto_Parthian : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansInscriptionalParthian-Regular.ttf";
   Noto_Pahlavi  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansInscriptionalPahlavi-Regular.ttf";
   Noto_Psalter  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansPsalterPahlavi-Regular.ttf";
   Noto_Old_South_Arabian : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOldSouthArabian-Regular.ttf";
   Noto_Old_North_Arabian : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOldNorthArabian-Regular.ttf";
   Noto_Manichaean : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansManichaean-Regular.ttf";
   Noto_Deva     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf";
   Noto_Bengali  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansBengali-Regular.ttf";
   Noto_Gurmukhi : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansGurmukhi-Regular.ttf";
   Noto_Gujarati : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansGujarati-Regular.ttf";
   Noto_Oriya    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOriya-Regular.ttf";
   Noto_Tamil    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTamil-Regular.ttf";
   Noto_Telugu   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTelugu-Regular.ttf";
   Noto_Kannada  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKannada-Regular.ttf";
   Noto_Malayalam : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMalayalam-Regular.ttf";
   Noto_Sinhala  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSinhala-Regular.ttf";
   Noto_Brahmi    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansBrahmi-Regular.ttf";
   Noto_Kaithi    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKaithi-Regular.ttf";
   Noto_Chakma    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansChakma-Regular.ttf";
   Noto_Mahajani  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMahajani-Regular.ttf";
   Noto_Sharada   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSharada-Regular.ttf";
   Noto_Khojki    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKhojki-Regular.ttf";
   Noto_Khudawadi : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKhudawadi-Regular.ttf";
   Noto_Grantha   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansGrantha-Regular.ttf";
   Noto_Newa      : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansNewa-Regular.ttf";
   Noto_Tirhuta   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTirhuta-Regular.ttf";
   Noto_Siddham   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSiddham-Regular.ttf";
   Noto_Modi      : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansModi-Regular.ttf";
   Noto_Takri     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTakri-Regular.ttf";
   Noto_Ahom      : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansAhom-Regular.ttf";
   Noto_Dogra     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansDogra-Regular.ttf";
   Noto_Warang    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansWarangCiti-Regular.ttf";
   Noto_Dives     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansDivesAkuru-Regular.ttf";
   Noto_Nandinagari : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansNandinagari-Regular.ttf";
   Noto_Zanabazar : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansZanabazarSquare-Regular.ttf";
   Noto_Soyombo   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSoyombo-Regular.ttf";
   Noto_Thai     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansThai-Regular.ttf";
   Noto_Lao      : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLao-Regular.ttf";
   Noto_Myanmar  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMyanmar-Regular.ttf";
   Noto_Limbu    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLimbu-Regular.ttf";
   Noto_Tai_Le   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTaiLe-Regular.ttf";
   Noto_New_Tai_Lue : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansNewTaiLue-Regular.ttf";
   Noto_Khmer    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKhmer-Regular.ttf";
   Noto_Balinese : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansBalinese-Regular.ttf";
   Noto_Sundanese : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSundanese-Regular.ttf";
   Noto_Batak    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansBatak-Regular.ttf";
   Noto_Lepcha   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLepcha-Regular.ttf";
   Noto_Ol_Chiki : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOlChiki-Regular.ttf";
   Noto_Syloti   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSylotiNagri-Regular.ttf";
   Noto_Phags_Pa : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansPhagsPa-Regular.ttf";
   Noto_Saurashtra : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansSaurashtra-Regular.ttf";
   Noto_Kayah_Li : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansKayahLi-Regular.ttf";
   Noto_Rejang   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansRejang-Regular.ttf";
   Noto_Javanese : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansJavanese-Regular.ttf";
   Noto_Cham     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansCham-Regular.ttf";
   Noto_Tai_Viet : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansTaiViet-Regular.ttf";
   Noto_Meetei   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMeeteiMayek-Regular.ttf";
   Noto_Linear_A : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLinearA-Regular.ttf";
   Noto_Linear_B : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLinearB-Regular.ttf";
   Noto_Cuneiform : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansCuneiform-Regular.ttf";
   Noto_Lycian   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLycian-Regular.ttf";
   Noto_Carian   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansCarian-Regular.ttf";
   Noto_Old_Turkic : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOldTurkic-Regular.ttf";
   Noto_Medefaidrin : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMedefaidrin-Regular.ttf";
   Noto_Wancho   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansWancho-Regular.ttf";
   Noto_Deseret  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansDeseret-Regular.ttf";
   Noto_Shavian  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansShavian-Regular.ttf";
   Noto_Osmanya  : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOsmanya-Regular.ttf";
   Noto_Osage    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansOsage-Regular.ttf";
   Noto_Bamum    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansBamum-Regular.ttf";
   Noto_Lisu     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansLisu-Regular.ttf";
   Noto_Miao     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMiao-Regular.ttf";
   Noto_Nushu    : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansNushu-Regular.ttf";
   Noto_Tangut   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSerifTangut-Regular.ttf";
   Noto_Khitan   : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSerifKhitanSmallScript-Regular.ttf";
   Noto_CJK      : aliased constant String := "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc";
   VL_Gothic     : aliased constant String := "/usr/share/fonts/truetype/vlgothic/VL-Gothic-Regular.ttf";
   VL_PGothic    : aliased constant String := "/usr/share/fonts/truetype/vlgothic/VL-PGothic-Regular.ttf";

   --  Colour emoji, of the layered kind only. Textrender draws a COLR/CPAL glyph
   --  from outlines and a palette, which needs nothing from the caller; the
   --  bitmap kinds hold PNGs and want a decoder this application does not carry,
   --  which is why NotoColorEmoji stays on the unsupported list below.
   Twemoji       : aliased constant String := "/usr/share/fonts/truetype/twemoji/TwemojiMozilla.ttf";
   Twemoji_TTF   : aliased constant String := "/usr/share/fonts/TTF/TwemojiMozilla.ttf";
   Segoe_Emoji   : aliased constant String := "C:\Windows\Fonts\seguiemj.ttf";

   Primary_Candidates : constant Candidate_Array :=
     [Noto_Mono'Access,
      DejaVu_Mono'Access,
      Liberation2'Access,
      Liberation'Access,
      Noto_Old_Mono'Access];

   Fallback_Candidates : constant Candidate_Array :=
     [DejaVu_Mono'Access,
      DejaVu_Sans'Access,
      VL_Gothic'Access,
      VL_PGothic'Access,
      Noto_Sans'Access,
      Noto_Symbols'Access,
      Noto_Symbols2'Access,
      Noto_Arabic'Access,
      Noto_Hebrew'Access,
      Noto_Samaritan'Access,
      Noto_Mandaic'Access,
      Noto_Adlam'Access,
      Noto_Rohingya'Access,
      Noto_Aramaic'Access,
      Noto_Palmyrene'Access,
      Noto_Nabataean'Access,
      Noto_Hatran'Access,
      Noto_Phoenician'Access,
      Noto_Lydian'Access,
      Noto_Avestan'Access,
      Noto_Parthian'Access,
      Noto_Pahlavi'Access,
      Noto_Psalter'Access,
      Noto_Old_South_Arabian'Access,
      Noto_Old_North_Arabian'Access,
      Noto_Manichaean'Access,
      Noto_Deva'Access,
      Noto_Bengali'Access,
      Noto_Gurmukhi'Access,
      Noto_Gujarati'Access,
      Noto_Oriya'Access,
      Noto_Tamil'Access,
      Noto_Telugu'Access,
      Noto_Kannada'Access,
      Noto_Malayalam'Access,
      Noto_Sinhala'Access,
      Noto_Brahmi'Access,
      Noto_Kaithi'Access,
      Noto_Chakma'Access,
      Noto_Mahajani'Access,
      Noto_Sharada'Access,
      Noto_Khojki'Access,
      Noto_Khudawadi'Access,
      Noto_Grantha'Access,
      Noto_Newa'Access,
      Noto_Tirhuta'Access,
      Noto_Siddham'Access,
      Noto_Modi'Access,
      Noto_Takri'Access,
      Noto_Ahom'Access,
      Noto_Dogra'Access,
      Noto_Warang'Access,
      Noto_Dives'Access,
      Noto_Nandinagari'Access,
      Noto_Zanabazar'Access,
      Noto_Soyombo'Access,
      Noto_Thai'Access,
      Noto_Lao'Access,
      Noto_Myanmar'Access,
      Noto_Limbu'Access,
      Noto_Tai_Le'Access,
      Noto_New_Tai_Lue'Access,
      Noto_Khmer'Access,
      Noto_Balinese'Access,
      Noto_Sundanese'Access,
      Noto_Batak'Access,
      Noto_Lepcha'Access,
      Noto_Ol_Chiki'Access,
      Noto_Syloti'Access,
      Noto_Phags_Pa'Access,
      Noto_Saurashtra'Access,
      Noto_Kayah_Li'Access,
      Noto_Rejang'Access,
      Noto_Javanese'Access,
      Noto_Cham'Access,
      Noto_Tai_Viet'Access,
      Noto_Meetei'Access,
      Noto_Linear_A'Access,
      Noto_Linear_B'Access,
      Noto_Cuneiform'Access,
      Noto_Lycian'Access,
      Noto_Carian'Access,
      Noto_Old_Turkic'Access,
      Noto_Medefaidrin'Access,
      Noto_Wancho'Access,
      Noto_Deseret'Access,
      Noto_Shavian'Access,
      Noto_Osmanya'Access,
      Noto_Osage'Access,
      Noto_Bamum'Access,
      Noto_Lisu'Access,
      Noto_Miao'Access,
      Noto_Nushu'Access,
      Noto_Tangut'Access,
      Noto_Khitan'Access,
      Noto_CJK'Access,

      --  Last: an emoji font maps far more than emoji -- arrows, stars, the
      --  check mark -- so ahead of these it would capture characters they draw
      --  perfectly well.
      Twemoji'Access,
      Twemoji_TTF'Access,
      Segoe_Emoji'Access];

   Cached_Default_Path  : Font_Path;
   Cached_Default_Ready : Boolean := False;

   function Safe_Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;
      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Bounded (Text : String) return String is
      Result : String (1 .. Max_Status_Label_Length);
      Last   : Natural := 0;
   begin
      for Ch of Text loop
         exit when Last = Result'Last;
         Last := Last + 1;
         Result (Last) := Ch;
      end loop;
      return Result (1 .. Last);
   end Bounded;

   function To_Lower (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
      end loop;
      return Result;
   end To_Lower;

   function Has_Suffix (Text : String; Suffix : String) return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Has_Suffix;

   function Is_Font_File (Path : String) return Boolean is
      Lower : constant String := To_Lower (Path);
   begin
      return Has_Suffix (Lower, ".ttf")
        or else Has_Suffix (Lower, ".ttc")
        or else Has_Suffix (Lower, ".otf");
   end Is_Font_File;

   function Is_Ordinary_File (Path : String) return Boolean is
   begin
      return Path /= ""
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   exception
      when others =>
         return False;
   end Is_Ordinary_File;

   function Is_Known_Unsupported_Renderer_Font (Path : String) return Boolean is
      Lower : constant String := To_Lower (Ada.Directories.Simple_Name (Path));
   begin
      return Lower = "notocoloremoji.ttf"
        or else Lower = "unifont.ttf"
        or else Lower = "droidsansfallbackfull.ttf";
   exception
      when others =>
         return False;
   end Is_Known_Unsupported_Renderer_Font;

   function Is_Loadable_Font (Path : String) return Boolean is
      Font  : Textrender.Fonts.Font;
   begin
      if not Is_Font_File (Path)
        or else not Is_Ordinary_File (Path)
        or else Is_Known_Unsupported_Renderer_Font (Path)
      then
         return False;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return False;
      end if;

      Textrender.Fonts.Reset (Font);
      return True;
   exception
      when others =>
         Textrender.Fonts.Reset (Font);
         return False;
   end Is_Loadable_Font;

   function Make_Path (Text : String) return Font_Path is
      Result : Font_Path;
      Last   : constant Natural := Natural'Min (Text'Length, Result.Text'Length);
   begin
      Result.Length := Last;
      if Last > 0 then
         Result.Text (1 .. Last) := Text (Text'First .. Text'First + Last - 1);
      end if;
      return Result;
   end Make_Path;

   function To_String (Path : Font_Path) return String is
   begin
      if Path.Length = 0 then
         return "";
      end if;
      return Path.Text (1 .. Path.Length);
   end To_String;

   function Status_Label
     (Default_Path   : String;
      Fallback_Count : Natural) return String
   is
   begin
      if Default_Path = "" then
         return Bounded
           ("Fonts unavailable; fallbacks=" & Natural_Image (Fallback_Count));
      else
         declare
            Primary : constant String := Ada.Directories.Simple_Name (Default_Path);
         begin
            return Bounded
              ("Fonts ready; fallbacks="
               & Natural_Image (Fallback_Count)
               & "; primary="
               & Primary);
         end;
      end if;
   exception
      when others =>
         return Bounded
           ("Fonts ready; fallbacks="
            & Natural_Image (Fallback_Count)
            & "; primary="
            & Default_Path);
   end Status_Label;

   function Default_Font_Path return String is
      Override_Path : constant String := Safe_Environment_Value ("TERMINAL_FONT_PATH");
   begin
      if Cached_Default_Ready then
         return To_String (Cached_Default_Path);
      end if;

      if Is_Loadable_Font (Override_Path) then
         Cached_Default_Path := Make_Path (Override_Path);
         Cached_Default_Ready := True;
         return Override_Path;
      end if;

      for Candidate of Primary_Candidates loop
         if Is_Loadable_Font (Candidate.all) then
            Cached_Default_Path := Make_Path (Candidate.all);
            Cached_Default_Ready := True;
            return Candidate.all;
         end if;
      end loop;

      Cached_Default_Path := Make_Path ("");
      Cached_Default_Ready := True;
      return "";
   end Default_Font_Path;

   function Fallback_Font_Paths return Font_Path_Array is
      Primary : constant String := Default_Font_Path;
      Result  : Font_Path_Array (1 .. Max_Fallback_Fonts);
      Count   : Natural := 0;

      procedure Consider (Path : String) is
      begin
         if Path = "" or else Path = Primary or else Count = Max_Fallback_Fonts then
            return;
         end if;

         for I in 1 .. Count loop
            if To_String (Result (I)) = Path then
               return;
            end if;
         end loop;

         if Is_Loadable_Font (Path) then
            Count := Count + 1;
            Result (Count) := Make_Path (Path);
         end if;
      end Consider;
   begin
      for Candidate of Fallback_Candidates loop
         Consider (Candidate.all);
      end loop;

      --  A font the user installed for themselves, which is where a layered
      --  emoji font lands on a machine without root.
      if Ada.Environment_Variables.Exists ("HOME") then
         Consider
           (Ada.Environment_Variables.Value ("HOME")
            & "/.local/share/fonts/TwemojiMozilla.ttf");
      end if;

      if Count = 0 then
         return (1 .. 0 => <>);
      end if;
      return Result (1 .. Count);
   end Fallback_Font_Paths;
end Terminal.App.Fonts;
