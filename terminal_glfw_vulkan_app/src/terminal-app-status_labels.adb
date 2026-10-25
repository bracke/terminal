with Ada.Characters.Handling;

package body Terminal.App.Status_Labels is
   function Humanize (Text : String) return String is
      Result : String (1 .. Text'Length);
      At_Word_Start : Boolean := True;
   begin
      for I in Text'Range loop
         declare
            Ch : constant Character := Text (I);
            Out_Index : constant Positive := I - Text'First + 1;
         begin
            if Ch = '_' then
               Result (Out_Index) := ' ';
               At_Word_Start := True;
            elsif At_Word_Start then
               Result (Out_Index) := Ada.Characters.Handling.To_Upper (Ch);
               At_Word_Start := False;
            else
               Result (Out_Index) := Ada.Characters.Handling.To_Lower (Ch);
            end if;
         end;
      end loop;
      return Result;
   end Humanize;

   function Bounded
     (Text           : String;
      Maximum_Length : Positive) return String is
     (if Text'Length <= Maximum_Length
      then Text
      else Text (Text'First .. Text'First + Maximum_Length - 1));
end Terminal.App.Status_Labels;
