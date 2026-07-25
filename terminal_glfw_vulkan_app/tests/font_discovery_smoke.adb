with Ada.Directories;

with AUnit.Assertions;

with Terminal.App.Fonts;

procedure Font_Discovery_Smoke is
   use AUnit.Assertions;

   package Fonts renames Terminal.App.Fonts;

   Noto_Devanagari : constant String :=
     "/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf";

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

   if Ada.Directories.Exists (Noto_Devanagari) then
      Assert
        (Contains (Noto_Devanagari),
         "installed Devanagari fallback should be discovered");
   end if;
end Font_Discovery_Smoke;
