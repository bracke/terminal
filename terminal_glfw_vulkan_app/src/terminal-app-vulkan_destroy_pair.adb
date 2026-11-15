with Ada.Exceptions;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Vulkan_Destroy_Once;

procedure Terminal.App.Vulkan_Destroy_Pair
  (First   : in out First_Handle_Type;
   Second  : in out Second_Handle_Type;
   Success : out Boolean)
is
   First_Ok : Boolean;
   Second_Ok : Boolean;

   procedure Report_First
     (Occurrence : Ada.Exceptions.Exception_Occurrence) is
   begin
      Terminal.App.Cleanup_Diagnostics.Note_Failure
        (Failure_Source,
         Occurrence, First_Operation);
   end Report_First;

   procedure Report_Second
     (Occurrence : Ada.Exceptions.Exception_Occurrence) is
   begin
      Terminal.App.Cleanup_Diagnostics.Note_Failure
        (Failure_Source,
         Occurrence, Second_Operation);
   end Report_Second;

   procedure Destroy_First_Once is new Terminal.App.Vulkan_Destroy_Once
     (First_Handle_Type, Null_First, Destroy_First, Report_First);
   procedure Destroy_Second_Once is new Terminal.App.Vulkan_Destroy_Once
     (Second_Handle_Type, Null_Second, Destroy_Second, Report_Second);
begin
   Destroy_First_Once (First, First_Ok);
   if not First_Ok then
      Second := Null_Second;
      Success := False;
      return;
   end if;
   Destroy_Second_Once (Second, Second_Ok);
   Success := Second_Ok;
end Terminal.App.Vulkan_Destroy_Pair;
