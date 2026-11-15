with Ada.Text_IO;
with Unicode_Generator_Support;

procedure Unicode_Generator_Support_Smoke is
   procedure Expect_Invalid (Line : String) is
      First_CP : Natural;
      Last_CP  : Natural;
      Property : String (1 .. 8);
      Valid    : Boolean;
      Rejected : Boolean := False;
   begin
      begin
         Unicode_Generator_Support.Parse_Property_Line
           (Line, First_CP, Last_CP, Property, Valid);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      if not Rejected then
         raise Program_Error with "malformed Unicode range was accepted: " & Line;
      end if;
   end Expect_Invalid;

   procedure Expect_Invalid_Variation (Line : String) is
      Base     : Natural;
      Selector : Natural;
      Valid    : Boolean;
      Rejected : Boolean := False;
   begin
      begin
         Unicode_Generator_Support.Parse_Variation_Line
           (Line, Base, Selector, Valid);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      if not Rejected then
         raise Program_Error with
           "malformed Unicode variation was accepted: " & Line;
      end if;
   end Expect_Invalid_Variation;

   First_CP : Natural;
   Last_CP  : Natural;
   Property : String (1 .. 8);
   Valid    : Boolean;
   Base     : Natural;
   Selector : Natural;
   Empty    : constant Unicode_Generator_Support.Flag_Array_Access :=
     new Unicode_Generator_Support.Flag_Array'(0 .. 3 => False);
   Rejected_Empty : Boolean := False;
begin
   Expect_Invalid ("not a property line");
   Expect_Invalid ("; W");
   Expect_Invalid ("..; W");
   Expect_Invalid ("0041..; W");
   Expect_Invalid ("0041....0042; W");
   Expect_Invalid ("0041;");
   Expect_Invalid ("0041; W; extra");
   Unicode_Generator_Support.Parse_Property_Line
     ("0041..005A; W # letters", First_CP, Last_CP, Property, Valid);
   if not Valid
     or else First_CP /= 16#41#
     or else Last_CP /= 16#5A#
     or else Property (1) /= 'W'
   then
      raise Program_Error with "valid Unicode range was not parsed";
   end if;
   Expect_Invalid_Variation ("not a variation line");
   Expect_Invalid_Variation ("0023; emoji style;");
   Expect_Invalid_Variation ("0023 1234 ; emoji style;");
   Expect_Invalid_Variation ("0023 FE0F ; unknown style;");
   Expect_Invalid_Variation ("0023 FE0E ; emoji style;");
   Unicode_Generator_Support.Parse_Variation_Line
     ("0023 FE0F ; emoji style; # number sign", Base, Selector, Valid);
   if not Valid or else Base /= 16#23# or else Selector /= 16#FE0F# then
      raise Program_Error with "valid Unicode variation was not parsed";
   end if;
   begin
      Unicode_Generator_Support.Write_Intervals
        (Ada.Text_IO.Standard_Output, "Empty_Intervals", Empty);
   exception
      when Constraint_Error =>
         Rejected_Empty := True;
   end;
   if not Rejected_Empty then
      raise Program_Error with "empty Unicode interval set was emitted";
   end if;
end Unicode_Generator_Support_Smoke;
