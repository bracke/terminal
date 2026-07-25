with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;

with Textrender.Fonts;

package body Terminal.App.Fonts is
   use type Ada.Directories.File_Kind;
   use type Textrender.Fonts.Glyph_Lookup_Result;
   use type Textrender.Fonts.Load_Result;

   type Candidate_Array is array (Positive range <>) of access constant String;

   Noto_Mono     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf";
   DejaVu_Mono   : aliased constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
   Liberation2   : aliased constant String := "/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf";
   Liberation    : aliased constant String := "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf";
   Noto_Old_Mono : aliased constant String := "/usr/share/fonts/truetype/noto/NotoMono-Regular.ttf";
   DejaVu_Sans   : aliased constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";
   Noto_Sans     : aliased constant String := "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf";
   VL_Gothic     : aliased constant String := "/usr/share/fonts/truetype/vlgothic/VL-Gothic-Regular.ttf";
   VL_PGothic    : aliased constant String := "/usr/share/fonts/truetype/vlgothic/VL-PGothic-Regular.ttf";

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
      Noto_Sans'Access];

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
      return Has_Suffix (Lower, ".ttf") or else Has_Suffix (Lower, ".ttc");
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
      Glyph : Textrender.Fonts.Glyph_Info;
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

      if Textrender.Fonts.Lookup_Glyph
           (Font, Textrender.Fonts.Codepoint (Character'Pos ('?')), Glyph)
         /= Textrender.Fonts.Glyph_Found
      then
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

      if Count = 0 then
         return (1 .. 0 => <>);
      end if;
      return Result (1 .. Count);
   end Fallback_Font_Paths;
end Terminal.App.Fonts;
