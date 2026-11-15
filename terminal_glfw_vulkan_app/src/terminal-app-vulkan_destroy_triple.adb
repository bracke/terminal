with Ada.Exceptions;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.App.Vulkan_Destroy_Once;

procedure Terminal.App.Vulkan_Destroy_Triple
  (First   : in out First_Handle_Type;
   Second  : in out Second_Handle_Type;
   Third   : in out Third_Handle_Type;
   Success : out Boolean)
is
   First_Ok : Boolean;
   Tail_Ok : Boolean;

   procedure Report_First
     (Occurrence : Ada.Exceptions.Exception_Occurrence) is
   begin
      Terminal.App.Cleanup_Diagnostics.Note_Failure
        (Failure_Source,
         Occurrence, First_Operation);
   end Report_First;

   procedure Destroy_First_Once is new Terminal.App.Vulkan_Destroy_Once
     (First_Handle_Type, Null_First, Destroy_First, Report_First);

   procedure Destroy_Tail is new Terminal.App.Vulkan_Destroy_Pair
     (Second_Handle_Type, Null_Second, Second_Operation, Destroy_Second,
      Third_Handle_Type, Null_Third, Third_Operation, Destroy_Third,
      Failure_Source);
begin
   Destroy_First_Once (First, First_Ok);
   if not First_Ok then
      Second := Null_Second;
      Third := Null_Third;
      Success := False;
      return;
   end if;
   Destroy_Tail (Second, Third, Tail_Ok);
   Success := Tail_Ok;
end Terminal.App.Vulkan_Destroy_Triple;
