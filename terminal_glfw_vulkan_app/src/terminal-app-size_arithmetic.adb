package body Terminal.App.Size_Arithmetic is
   function Try_Add
     (Left, Right : Natural;
      Result      : out Natural) return Boolean
   is
   begin
      if Right > Natural'Last - Left then
         Result := 0;
         return False;
      end if;
      Result := Left + Right;
      return True;
   end Try_Add;

   function Try_Multiply
     (Left, Right : Natural;
      Result      : out Natural) return Boolean
   is
   begin
      if Left /= 0 and then Right > Natural'Last / Left then
         Result := 0;
         return False;
      end if;
      Result := Left * Right;
      return True;
   end Try_Multiply;
end Terminal.App.Size_Arithmetic;
