with Terminal.Core.Character_Properties_Data;

package body Terminal.Core.Character_Properties is
   package Data renames Character_Properties_Data;

   function Contains
     (Items : Data.Interval_Array;
      Value : Natural) return Boolean
   is
      First : Natural := Items'First;
      Last  : Natural := Items'Last;
   begin
      while First <= Last loop
         declare
            Middle : constant Natural := First + (Last - First) / 2;
         begin
            if Value < Items (Middle).First then
               exit when Middle = Items'First;
               Last := Middle - 1;
            elsif Value > Items (Middle).Last then
               First := Middle + 1;
            else
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains;

   function Is_Wide (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return Contains (Data.Wide_Intervals, V);
   end Is_Wide;

   function Is_Emoji_Variation_Base
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return Contains (Data.Emoji_Variation_Base_Intervals, V);
   end Is_Emoji_Variation_Base;

   function Is_Keycap_Base
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return V = 16#23# or else V = 16#2A# or else V in 16#30# .. 16#39#;
   end Is_Keycap_Base;

   function Is_Regional_Indicator
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return V in 16#1F1E6# .. 16#1F1FF#;
   end Is_Regional_Indicator;

   function Is_Emoji_Modifier
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return V in 16#1F3FB# .. 16#1F3FF#;
   end Is_Emoji_Modifier;

   function Is_Zero_Width
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return Contains (Data.Zero_Width_Intervals, V);
   end Is_Zero_Width;

   function Is_Renderable_Attachment
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return Contains (Data.Renderable_Attachment_Intervals, V);
   end Is_Renderable_Attachment;
end Terminal.Core.Character_Properties;
