program TimerQueues;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMain in 'FMain.pas' {FormMain};

{$R *.res}

begin
  ReportMemoryLeaksOnShutDown := True;

  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
