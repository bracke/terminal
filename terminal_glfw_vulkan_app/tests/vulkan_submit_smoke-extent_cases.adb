separate (Vulkan_Submit_Smoke)
procedure Extent_Cases is
begin
   Reset_Fixture;
   declare
   begin
      Frame.Width := 0;
      VS.Build (Frame, Batch, Status);
      Assert (Status = VS.Invalid_Frame, "zero-width frame should be rejected");
      Assert
        (VS.Status_Label (Status) = "Submit build: Invalid Frame",
         "invalid submit status label");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("zero frame extent", E);
   end;
end Extent_Cases;
