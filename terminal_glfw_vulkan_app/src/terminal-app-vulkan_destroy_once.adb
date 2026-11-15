procedure Terminal.App.Vulkan_Destroy_Once
  (Handle  : in out Handle_Type;
   Success : out Boolean)
is
   Owned : Handle_Type;
begin
   Success := True;
   if Handle = Null_Handle then
      return;
   end if;
   Owned := Handle;
   Handle := Null_Handle;
   Destroy (Owned);
exception
   when E : others =>
      --  Repeat the assignment in the handler for by-reference actuals; the
      --  normal return below also performs copy-back for scalar actuals.
      Handle := Null_Handle;
      Success := False;
      begin
         Report_Failure (E);
      exception
         when others => null;
      end;
end Terminal.App.Vulkan_Destroy_Once;
