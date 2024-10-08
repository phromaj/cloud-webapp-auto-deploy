from sqlalchemy import Column, Integer
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class VisitCounter(Base):
    __tablename__ = 'visit_counter'
    id = Column(Integer, primary_key=True, index=True)
    count = Column(Integer, default=0)
