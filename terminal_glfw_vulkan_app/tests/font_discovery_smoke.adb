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
   Noto_Khmer : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansKhmer-Regular.ttf";
   Noto_Tai_Viet : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansTaiViet-Regular.ttf";
   Noto_Meetei : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansMeeteiMayek-Regular.ttf";

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
   Assert_Contains_If_Installed (Noto_Khmer, "Khmer");
   Assert_Contains_If_Installed (Noto_Tai_Viet, "Tai Viet");
   Assert_Contains_If_Installed (Noto_Meetei, "Meetei Mayek");
end Font_Discovery_Smoke;
