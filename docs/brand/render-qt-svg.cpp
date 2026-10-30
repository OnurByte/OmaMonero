#include <QGuiApplication>
#include <QSvgRenderer>
#include <QPainter>
#include <QImage>
int main(int argc,char **argv){QGuiApplication a(argc,argv);QSvgRenderer svg{QString(argv[1])}; if(!svg.isValid())return 2;QImage im(1090,1080,QImage::Format_ARGB32_Premultiplied);im.fill(Qt::transparent);QPainter p(&im);svg.render(&p);p.end();return im.save(argv[2])?0:3;}
