
backgnd_file="./cumul_spec_backgnd.dat";
spec_file="./cumul_spec.dat";
cumul_spec_backgnd=load(backgnd_file);
cumul_spec=load(spec_file);



dspec=diff(cumul_spec(:,3));
dbackgnd=diff(cumul_spec_backgnd(:,3));
x=cumul_spec(:,2);
diffx=diff(x);
dx=x(1:end-1)+diffx./2;



bar(dx,dspec);
hold
bar(dx,dbackgnd,"facecolor","r");
xlabel("threshold setting");
ylabel("counts");
title("spectrum of Am source, 75 s per bin, -2750 to -759");
hold off


